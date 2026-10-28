<?xml version="1.0" encoding="UTF-8"?>
<!-- scratchpad.xsl: XSLT view of the Mirror Duck XML scratchpad.
     Transforms mirror-duck XML into a readable HTML page.
     Run with: xsltproc xml/scratchpad.xsl out/scratchpad.xml -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>
  <xsl:template match="/mirror-duck">
    <html>
      <head><title>Mirror Duck — Evidence-Sealed Artifact</title></head>
      <body>
        <h1>Mirror Duck — Evidence-Sealed Artifact</h1>
        <h2>Contract</h2>
        <table>
          <tr><td>Transform</td><td><xsl:value-of select="contract/transform"/></td></tr>
          <tr><td>Preserve row count</td><td><xsl:value-of select="contract/preserve_row_count"/></td></tr>
          <tr><td>Preserve timestamps</td><td><xsl:value-of select="contract/preserve_timestamps"/></td></tr>
          <tr><td>Missing stays missing</td><td><xsl:value-of select="contract/missing_stays_missing"/></td></tr>
          <tr><td>Sensor count</td><td><xsl:value-of select="contract/sensor_count"/></td></tr>
          <tr><td>First timestamp</td><td><xsl:value-of select="contract/first_timestamp"/></td></tr>
          <tr><td>Last timestamp</td><td><xsl:value-of select="contract/last_timestamp"/></td></tr>
          <tr><td>Row count</td><td><xsl:value-of select="contract/row_count"/></td></tr>
          <tr><td>Generator status</td><td><xsl:value-of select="contract/status"/></td></tr>
        </table>
        <h2>Entropy</h2>
        <table>
          <tr><td>Source</td><td><xsl:value-of select="entropy/source"/></td></tr>
          <tr><td>Sensor id</td><td><xsl:value-of select="entropy/sensor_id"/></td></tr>
          <tr><td>Bits</td><td><xsl:value-of select="entropy/bits"/></td></tr>
          <tr><td>Ones</td><td><xsl:value-of select="entropy/ones"/></td></tr>
        </table>
        <h2>Evidence</h2>
        <table>
          <tr><td>Status</td><td><xsl:value-of select="evidence/status"/></td></tr>
          <tr><td>Rows</td><td><xsl:value-of select="evidence/rows"/></td></tr>
        </table>
        <p>Only the independent checker may write VERIFIED_BY_CHECKER. The generator status above must remain proposed.</p>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
