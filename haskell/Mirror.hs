{- Mirror.hs: Haskell orchestration and AST layer for Mirror Duck.
   This is a second, independent implementation of the
   temperature transform check, in a different language
   from the C checker, so a bug shared by one language's
   code cannot silently pass both.
   AST: a transform is either MeanOverPresent, which maps
   every input row to one output row, or DropMissingRows,
   which filters out rows with any missing sensor.
   The contract requires row count preservation, so only
   MeanOverPresent can satisfy it on this file, where
   some rows have missing sensors. The program proves
   that point by counting how many rows DropMissingRows
   would drop, instead of merely asserting it.
   Usage: mirror-hs <input.csv> <mean.csv> <scratchpad.txt> <report.txt>
   Exit 0 only on PASS, 1 on any mismatch.
-}
module Main (main) where

import Data.List (isPrefixOf)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import System.IO (hPutStrLn, stderr)

data Transform = MeanOverPresent | DropMissingRows deriving (Eq, Show)

data Contract = Contract
  { preserveRows :: Bool
  , preserveTimestamps :: Bool
  , missingStaysMissing :: Bool
  , sensorCount :: Int
  , rowCountClaim :: Int
  , firstTsClaim :: Int
  , lastTsClaim :: Int
  , entropySource :: String
  , transformName :: String
  , statusClaim :: String
  } deriving (Show)

data Row = Row
  { rowTs :: Int
  , rowValues :: [Maybe Int]
  } deriving (Show)

splitComma :: String -> [String]
splitComma [] = [""]
splitComma s =
  let (field, rest) = break (== ',') s
  in case rest of
       [] -> [field]
       (_ : tail') -> field : splitComma tail'

parseInt :: String -> Maybe Int
parseInt s = case reads s of
  [(n, "")] -> Just n
  _ -> Nothing

parseRow :: Int -> String -> Maybe Row
parseRow ns line =
  let fields = splitComma line
  in if length fields < 3 + ns || head fields /= "13"
     then Nothing
     else case parseInt (fields !! 1) of
       Nothing -> Nothing
       Just ts ->
         let vals = map (\v -> if null v then Nothing else parseInt v) (take ns (drop 3 fields))
         in Just (Row ts vals)

meanOf :: Row -> (Double, Int)
meanOf row =
  let present = [v | Just v <- rowValues row]
      n = length present
  in if n == 0 then (0.0, 0) else (fromIntegral (sum present) / fromIntegral n, n)

evalTransform :: Transform -> Row -> Maybe (Double, Int)
evalTransform MeanOverPresent row = Just (meanOf row)
evalTransform DropMissingRows row =
  if all (\v -> case v of Just _ -> True; Nothing -> False) (rowValues row)
  then Just (meanOf row)
  else Nothing

parseContract :: String -> Maybe Contract
parseContract content =
  let kv line = case break (== '=') line of
        (k, '=' : v) -> Just (k, v)
        _ -> Nothing
      pairs = [p | Just p <- map kv (lines content)]
      look k = lookup k pairs
      boolVal s = s == "1"
  in case (look "preserve_row_count", look "preserve_timestamps",
          look "missing_stays_missing", look "sensor_count",
          look "row_count", look "first_timestamp", look "last_timestamp",
          look "entropy_source", look "transform", look "status") of
       (Just pr, Just pt, Just mm, Just sc, Just rc, Just ft, Just lt, Just es, Just tr, Just st) ->
         case (parseInt sc, parseInt rc, parseInt ft, parseInt lt) of
           (Just sc', Just rc', Just ft', Just lt') ->
             Just (Contract (boolVal pr) (boolVal pt) (boolVal mm) sc' rc' ft' lt' es tr st)
           _ -> Nothing
       _ -> Nothing

parseMean :: String -> Maybe (Int, Double, Int)
parseMean line =
  let fields = splitComma line
  in if length fields /= 3
     then Nothing
     else case (parseInt (fields !! 0), reads (fields !! 1) :: [(Double, String)], parseInt (fields !! 2)) of
       (Just ts, [(m, "")], Just n) -> Just (ts, m, n)
       _ -> Nothing

main :: IO ()
main = do
  args <- getArgs
  case args of
    [inputPath, meanPath, scratchPath, reportPath] -> run inputPath meanPath scratchPath reportPath
    _ -> do
      hPutStrLn stderr "usage: mirror-hs <input.csv> <mean.csv> <scratchpad.txt> <report.txt>"
      exitFailure

run :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
run inputPath meanPath scratchPath reportPath = do
  inputContent <- readFile inputPath
  meanContent <- readFile meanPath
  scratchContent <- readFile scratchPath
  -- The supplied file uses CRLF line endings. Haskell's lines
  -- strips only LF, leaving a CR on the last field, which
  -- would make the last sensor value unparseable. Strip CRs
  -- before parsing; the C reader already treats CR as a
  -- field terminator, which is why it passed first.
  let inputLines = map (filter (/= '\r')) (lines inputContent)
      sensorLines = [l | l <- inputLines, "12," `isPrefixOf` l]
      ns = case sensorLines of
        (l : _) -> length (drop 3 (splitComma l))
        [] -> 0
      rows = [r | Just r <- map (parseRow ns) inputLines]
      meanRows = [m | Just m <- map parseMean (drop 1 (map (filter (/= '\r')) (lines meanContent)))]
      contract = parseContract (filter (/= '\r') scratchContent)
  let failures = checkAll rows meanRows contract ns
      droppedByFilter = length [r | r <- rows, evalTransform DropMissingRows r == Nothing]
      reportLines =
        [ "HASKELL_ORCHESTRATION"
        , "rows=" ++ show (length rows)
        , "mean_rows=" ++ show (length meanRows)
        , "sensors=" ++ show ns
        , "filter_would_drop_rows=" ++ show droppedByFilter
        , "contract=" ++ show contract
        ] ++ failures
      passed = null failures
  writeFile reportPath (unlines (reportLines ++ ["result=" ++ if passed then "PASS" else "FAIL"]))
  if passed
    then do
      putStrLn ("haskell: PASS rows=" ++ show (length rows) ++ " filter_would_drop=" ++ show droppedByFilter)
      exitSuccess
    else do
      mapM_ (hPutStrLn stderr) failures
      hPutStrLn stderr ("haskell: FAIL filter_would_drop=" ++ show droppedByFilter)
      exitFailure

checkAll :: [Row] -> [(Int, Double, Int)] -> Maybe Contract -> Int -> [String]
checkAll rows meanRows mcontract ns =
  case mcontract of
    Nothing -> ["contract parse failed"]
    Just c ->
      concat
        [ if transformName c /= "per_second_mean_over_present_sensors" then ["contract transform mismatch"] else []
        , if not (preserveRows c && preserveTimestamps c && missingStaysMissing c) then ["contract weakened"] else []
        , if statusClaim c /= "proposed" then ["contract status is not proposed"] else []
        , if entropySource c /= "temperature_delta_parity" then ["contract entropy source mismatch"] else []
        , if sensorCount c /= ns then ["contract sensor count mismatch"] else []
        , if rowCountClaim c /= length rows then ["contract row count mismatch"] else []
        , if null rows then ["no input rows"] else
            let firstTs = rowTs (head rows)
                lastTs = rowTs (last rows)
            in concat
                 [ if firstTsClaim c /= firstTs then ["contract first timestamp mismatch"] else []
                 , if lastTsClaim c /= lastTs then ["contract last timestamp mismatch"] else []
                 ]
        , if length meanRows /= length rows then ["mean row count mismatch"] else []
        , take 10
            [ "mean mismatch at row " ++ show i ++ " ts=" ++ show (rowTs row) ++ " mts=" ++ show mts ++ " mmean=" ++ show mmean ++ " expect=" ++ show expect ++ " mpresent=" ++ show mpresent ++ " present=" ++ show present ++ " values=" ++ show (rowValues row)
            | (i, (row, (mts, mmean, mpresent))) <- zip [0 :: Int ..] (zip rows meanRows)
            , let (expect, present) = meanOf row
            , mts /= rowTs row || mpresent /= present || abs (mmean - expect) > 0.000002
            ]
        , if not (null rows) && not (all (\(prev, curr) -> rowTs curr == rowTs prev + 1) (zip rows (tail rows)))
          then ["timestamps not contiguous"] else []
        ]
