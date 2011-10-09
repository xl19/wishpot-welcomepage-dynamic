<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet version='1.0' 
 xmlns:xsl='http://www.w3.org/1999/XSL/Transform'
 xmlns:wp="http://www.wishpot.com/schemas/wishpot.dtd">

<xsl:output method='html' version='1.0' encoding='utf-8' indent='no'/>

<xsl:template match="/">
	<ol class="fluid items size4 fullborder containfloat">  
      <xsl:for-each select="rss/channel/item">
        <li>
			<div class="border">
				<div class="top">
					<a>
						<xsl:attribute name="href">
    						<xsl:value-of select="link" />
  						</xsl:attribute>
						<img>
							<xsl:attribute name="src">
    							<xsl:value-of select="wp:SmallImage/wp:url" />
  							</xsl:attribute>
						</img>
					</a>
				</div>
				<div class="bottom">
					<div class="info1">
						<a>
							<xsl:attribute name="href">
    							<xsl:value-of select="link" />
  							</xsl:attribute>
							<xsl:value-of select="title"/>
						</a>
					</div>
					<div class="info2">
						<xsl:value-of select="wp:PriceDisplay"/>
					</div>
				</div>
			
			</div>
		</li>
      </xsl:for-each>
    </ol>
</xsl:template>

</xsl:stylesheet>