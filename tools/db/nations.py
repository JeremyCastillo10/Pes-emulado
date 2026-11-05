# Selecciones FIFA: código|nombre|confederación|color camiseta|color secundario|fuerza(0-100)|grupo de nombres
NATIONS = """
ALB|Albania|UEFA|#e41e20|#000000|66|slav
AND|Andorra|UEFA|#1c3f94|#fedf00|42|es
ARM|Armenia|UEFA|#d90012|#0033a0|58|slav
AUT|Austria|UEFA|#ed2939|#ffffff|76|de
AZE|Azerbaiyán|UEFA|#0092bc|#ffffff|55|tr
BLR|Bielorrusia|UEFA|#cf101a|#ffffff|57|slav
BEL|Bélgica|UEFA|#e30613|#000000|80|nl
BIH|Bosnia y Herzegovina|UEFA|#002395|#fecb00|66|slav
BUL|Bulgaria|UEFA|#ffffff|#00966e|60|slav
CRO|Croacia|UEFA|#ffffff|#d60b0b|80|slav
CYP|Chipre|UEFA|#1e40a0|#ffffff|54|gr
CZE|Chequia|UEFA|#d7141a|#11457e|72|slav
DEN|Dinamarca|UEFA|#c8102e|#ffffff|77|nordic
ENG|Inglaterra|UEFA|#ffffff|#1d2a5b|86|en
EST|Estonia|UEFA|#0072ce|#000000|50|nordic
FRO|Islas Feroe|UEFA|#ffffff|#0065bd|48|nordic
FIN|Finlandia|UEFA|#ffffff|#002f6c|62|nordic
FRA|Francia|UEFA|#1f2a5c|#ffffff|88|fr
GEO|Georgia|UEFA|#ffffff|#e2001a|68|slav
GER|Alemania|UEFA|#ffffff|#000000|85|de
GIB|Gibraltar|UEFA|#e10b17|#ffffff|40|en
GRE|Grecia|UEFA|#ffffff|#0d5eaf|68|gr
HUN|Hungría|UEFA|#cd2a3e|#436f4d|70|slav
ISL|Islandia|UEFA|#02529c|#ffffff|62|nordic
ISR|Israel|UEFA|#ffffff|#0038b8|62|ar
ITA|Italia|UEFA|#0b5cba|#ffffff|83|it
KAZ|Kazajistán|UEFA|#00afca|#fec50c|56|tr
KOS|Kosovo|UEFA|#244aa5|#d0a650|58|slav
LVA|Letonia|UEFA|#9e3039|#ffffff|50|slav
LIE|Liechtenstein|UEFA|#002b7f|#ce1126|42|de
LTU|Lituania|UEFA|#fdb913|#006a44|52|slav
LUX|Luxemburgo|UEFA|#ef3340|#ffffff|55|fr
MLT|Malta|UEFA|#cf142b|#ffffff|45|it
MDA|Moldavia|UEFA|#0046ae|#ffd200|48|slav
MNE|Montenegro|UEFA|#c40308|#d3ae3b|60|slav
NED|Países Bajos|UEFA|#ff6200|#ffffff|84|nl
MKD|Macedonia del Norte|UEFA|#d20000|#ffe600|58|slav
NIR|Irlanda del Norte|UEFA|#008751|#ffffff|60|en
NOR|Noruega|UEFA|#ba0c2f|#ffffff|76|nordic
POL|Polonia|UEFA|#ffffff|#dc143c|72|slav
POR|Portugal|UEFA|#c8102e|#046a38|86|pt
IRL|Irlanda|UEFA|#169b62|#ffffff|64|en
ROU|Rumania|UEFA|#fcd116|#002b7f|68|slav
RUS|Rusia|UEFA|#ffffff|#0039a6|68|slav
SMR|San Marino|UEFA|#5eb6e4|#ffffff|35|it
SCO|Escocia|UEFA|#0b1f4f|#ffffff|68|en
SRB|Serbia|UEFA|#c6363c|#0c4076|72|slav
SVK|Eslovaquia|UEFA|#0b4ea2|#ffffff|68|slav
SVN|Eslovenia|UEFA|#ffffff|#005ce5|66|slav
ESP|España|UEFA|#c60b1e|#1d2a5b|88|es
SWE|Suecia|UEFA|#fecc02|#006aa7|72|nordic
SUI|Suiza|UEFA|#d52b1e|#ffffff|76|de
TUR|Turquía|UEFA|#e30a17|#ffffff|76|tr
UKR|Ucrania|UEFA|#ffd500|#005bbb|72|slav
WAL|Gales|UEFA|#c8102e|#ffffff|66|en
ARG|Argentina|CONMEBOL|#75aadb|#ffffff|88|es
BOL|Bolivia|CONMEBOL|#007934|#ffffff|58|es
BRA|Brasil|CONMEBOL|#ffdf00|#0b3d91|87|pt
CHI|Chile|CONMEBOL|#d52b1e|#0039a6|68|es
COL|Colombia|CONMEBOL|#fcd116|#003893|80|es
ECU|Ecuador|CONMEBOL|#ffdd00|#034ea2|76|es
PAR|Paraguay|CONMEBOL|#d52b1e|#ffffff|72|es
PER|Perú|CONMEBOL|#ffffff|#d91023|66|es
URU|Uruguay|CONMEBOL|#5ba3dc|#000000|81|es
VEN|Venezuela|CONMEBOL|#7b1c2e|#ffffff|66|es
AIA|Anguila|CONCACAF|#00247d|#ff9900|30|en
ATG|Antigua y Barbuda|CONCACAF|#ce1126|#000000|38|en
ARU|Aruba|CONCACAF|#418fde|#fcd116|35|nl
BAH|Bahamas|CONCACAF|#00abc9|#fae042|32|en
BRB|Barbados|CONCACAF|#00267f|#ffc726|36|en
BLZ|Belice|CONCACAF|#003f87|#ce1126|36|en
BER|Bermudas|CONCACAF|#ce1126|#00205b|40|en
VGB|Islas Vírgenes Británicas|CONCACAF|#00247d|#ffffff|30|en
CAN|Canadá|CONCACAF|#d80621|#ffffff|74|en
CAY|Islas Caimán|CONCACAF|#ce1126|#00247d|32|en
CRC|Costa Rica|CONCACAF|#ce1126|#002b7f|66|es
CUB|Cuba|CONCACAF|#cf142b|#002a8f|45|es
CUW|Curazao|CONCACAF|#002b7f|#f9e814|55|nl
DMA|Dominica|CONCACAF|#006b3f|#fcd116|34|en
DOM|República Dominicana|CONCACAF|#002d62|#ce1126|48|es
SLV|El Salvador|CONCACAF|#0f47af|#ffffff|50|es
GRN|Granada|CONCACAF|#ce1126|#fcd116|38|en
GUA|Guatemala|CONCACAF|#4997d0|#ffffff|54|es
GUY|Guyana|CONCACAF|#009e49|#fcd116|42|en
HAI|Haití|CONCACAF|#00209f|#d21034|52|fr
HON|Honduras|CONCACAF|#ffffff|#0073cf|58|es
JAM|Jamaica|CONCACAF|#fed100|#009b3a|60|en
MEX|México|CONCACAF|#006847|#ffffff|76|es
MSR|Montserrat|CONCACAF|#012169|#ffffff|30|en
NCA|Nicaragua|CONCACAF|#0067c6|#ffffff|45|es
PAN|Panamá|CONCACAF|#da121a|#005293|62|es
PUR|Puerto Rico|CONCACAF|#ed0000|#0050f0|42|es
SKN|San Cristóbal y Nieves|CONCACAF|#009e49|#ce1126|38|en
LCA|Santa Lucía|CONCACAF|#66ccff|#fcd116|35|en
VIN|San Vicente y las Granadinas|CONCACAF|#009e60|#fcd022|36|en
SUR|Surinam|CONCACAF|#377e3f|#b40a2d|50|nl
TRI|Trinidad y Tobago|CONCACAF|#ce1126|#000000|52|en
TCA|Islas Turcas y Caicos|CONCACAF|#00247d|#ffffff|28|en
USA|Estados Unidos|CONCACAF|#ffffff|#0a3161|76|en
VIR|Islas Vírgenes de EE. UU.|CONCACAF|#ffffff|#002868|28|en
ALG|Argelia|CAF|#ffffff|#006233|72|ar
ANG|Angola|CAF|#cc092f|#000000|58|pt
BEN|Benín|CAF|#008751|#fcd116|56|afr_fr
BOT|Botsuana|CAF|#75aadb|#000000|46|afr_en
BFA|Burkina Faso|CAF|#009e49|#ef2b2d|62|afr_fr
BDI|Burundi|CAF|#ce1126|#1eb53a|46|afr_fr
CMR|Camerún|CAF|#007a5e|#ce1126|70|afr_fr
CPV|Cabo Verde|CAF|#003893|#ffffff|62|pt
CTA|República Centroafricana|CAF|#003082|#ffce00|45|afr_fr
CHA|Chad|CAF|#002664|#fecb00|40|afr_fr
COM|Comoras|CAF|#3a75c4|#ffffff|48|afr_fr
CGO|Congo|CAF|#009543|#fbde4a|50|afr_fr
COD|RD Congo|CAF|#007fff|#f7d618|66|afr_fr
DJI|Yibuti|CAF|#6ab2e7|#12ad2b|32|afr_fr
EGY|Egipto|CAF|#ce1126|#ffffff|70|ar
EQG|Guinea Ecuatorial|CAF|#3e9a00|#e32118|54|es
ERI|Eritrea|CAF|#4189dd|#12ad2b|35|afr_en
SWZ|Esuatini|CAF|#3e5eb9|#ffd900|38|afr_en
ETH|Etiopía|CAF|#078930|#fcdd09|44|afr_en
GAB|Gabón|CAF|#009e60|#fcd116|58|afr_fr
GAM|Gambia|CAF|#ce1126|#0c1c8c|52|afr_en
GHA|Ghana|CAF|#ffffff|#000000|68|afr_en
GUI|Guinea|CAF|#ce1126|#009460|60|afr_fr
GNB|Guinea-Bisáu|CAF|#ce1126|#009e49|48|pt
CIV|Costa de Marfil|CAF|#f77f00|#ffffff|72|afr_fr
KEN|Kenia|CAF|#bb0000|#006600|48|afr_en
LES|Lesoto|CAF|#00209f|#ffffff|36|afr_en
LBR|Liberia|CAF|#002868|#bf0a30|42|afr_en
LBY|Libia|CAF|#e70013|#000000|50|ar
MAD|Madagascar|CAF|#fc3d32|#007e3a|48|afr_fr
MWI|Malaui|CAF|#ce1126|#000000|42|afr_en
MLI|Malí|CAF|#14b53a|#fcd116|66|afr_fr
MTN|Mauritania|CAF|#006233|#ffc400|50|ar
MRI|Mauricio|CAF|#ea2839|#1a206d|32|afr_en
MAR|Marruecos|CAF|#c1272d|#006233|80|ar
MOZ|Mozambique|CAF|#d21034|#000000|46|pt
NAM|Namibia|CAF|#003580|#d21034|45|afr_en
NIG|Níger|CAF|#e05206|#0db02b|42|afr_fr
NGA|Nigeria|CAF|#008751|#ffffff|72|afr_en
RWA|Ruanda|CAF|#00a1de|#fad201|42|afr_fr
STP|Santo Tomé y Príncipe|CAF|#12ad2b|#ffce00|30|pt
SEN|Senegal|CAF|#ffffff|#00853f|76|afr_fr
SEY|Seychelles|CAF|#003f87|#fcd856|28|afr_en
SLE|Sierra Leona|CAF|#1eb53a|#0072c6|44|afr_en
SOM|Somalia|CAF|#4189dd|#ffffff|28|ar
RSA|Sudáfrica|CAF|#ffb612|#007749|62|afr_en
SSD|Sudán del Sur|CAF|#0f47af|#da121a|35|afr_en
SDN|Sudán|CAF|#d21034|#ffffff|45|ar
TAN|Tanzania|CAF|#1eb53a|#00a3dd|45|afr_en
TOG|Togo|CAF|#006a4e|#ffce00|48|afr_fr
TUN|Túnez|CAF|#e70013|#ffffff|68|ar
UGA|Uganda|CAF|#fcdc04|#000000|50|afr_en
ZAM|Zambia|CAF|#198a00|#ef7d00|52|afr_en
ZIM|Zimbabue|CAF|#ffd200|#006400|48|afr_en
AFG|Afganistán|AFC|#d32011|#000000|35|ar
AUS|Australia|AFC|#ffcd00|#00843d|72|en
BHR|Baréin|AFC|#ce1126|#ffffff|54|ar
BAN|Bangladés|AFC|#006a4e|#f42a41|34|ar
BHU|Bután|AFC|#ffd520|#ff4e12|25|ar
BRU|Brunéi|AFC|#f7e017|#000000|28|ar
CAM|Camboya|AFC|#032ea1|#e00025|34|ko
CHN|China|AFC|#de2910|#ffde00|56|ko
TPE|China Taipéi|AFC|#0000ff|#fe0000|36|ko
GUM|Guam|AFC|#0033a0|#c8102e|28|en
HKG|Hong Kong|AFC|#de2910|#ffffff|40|ko
IND|India|AFC|#0b5fb4|#ff9933|42|ar
IDN|Indonesia|AFC|#e70011|#ffffff|52|ar
IRN|Irán|AFC|#ffffff|#da0000|70|ar
IRQ|Irak|AFC|#ffffff|#007a3d|62|ar
JPN|Japón|AFC|#0b2c7a|#ffffff|78|ja
JOR|Jordania|AFC|#ffffff|#ce1126|62|ar
PRK|Corea del Norte|AFC|#ed1c27|#024fa2|45|ko
KOR|Corea del Sur|AFC|#c60c30|#003478|76|ko
KUW|Kuwait|AFC|#0080ff|#ffffff|44|ar
KGZ|Kirguistán|AFC|#e8112d|#ffef00|42|tr
LAO|Laos|AFC|#ce1126|#002868|28|ko
LBN|Líbano|AFC|#ffffff|#ed1c24|46|ar
MAC|Macao|AFC|#00785e|#ffffff|22|ko
MAS|Malasia|AFC|#ffd700|#000000|46|ar
MDV|Maldivas|AFC|#d21034|#007e3a|28|ar
MNG|Mongolia|AFC|#c4272f|#015197|28|ko
MYA|Myanmar|AFC|#fecb00|#ea2839|36|ko
NEP|Nepal|AFC|#dc143c|#003893|32|ar
OMA|Omán|AFC|#db161b|#ffffff|56|ar
PAK|Pakistán|AFC|#01411c|#ffffff|30|ar
PLE|Palestina|AFC|#ffffff|#007a3d|50|ar
PHI|Filipinas|AFC|#0038a8|#ce1126|40|en
QAT|Catar|AFC|#8a1538|#ffffff|62|ar
KSA|Arabia Saudí|AFC|#ffffff|#006c35|64|ar
SIN|Singapur|AFC|#ef3340|#ffffff|36|ko
SRI|Sri Lanka|AFC|#8d153a|#ffbe29|26|ar
SYR|Siria|AFC|#ce1126|#ffffff|52|ar
TJK|Tayikistán|AFC|#cc0000|#006600|48|tr
THA|Tailandia|AFC|#241d4f|#a51931|50|ko
TLS|Timor Oriental|AFC|#dc241f|#000000|26|pt
TKM|Turkmenistán|AFC|#00843d|#ffffff|40|tr
UAE|Emiratos Árabes Unidos|AFC|#ffffff|#00732f|58|ar
UZB|Uzbekistán|AFC|#ffffff|#1eb53a|64|tr
VIE|Vietnam|AFC|#da251d|#ffff00|48|ko
YEM|Yemen|AFC|#ce1126|#ffffff|36|ar
ASA|Samoa Americana|OFC|#002868|#bf0a30|20|en
COK|Islas Cook|OFC|#00247d|#ffffff|24|en
FIJ|Fiyi|OFC|#ffffff|#68bfe5|36|en
NCL|Nueva Caledonia|OFC|#d52b1e|#0035ad|36|fr
NZL|Nueva Zelanda|OFC|#ffffff|#000000|56|en
PNG|Papúa Nueva Guinea|OFC|#ce1126|#000000|30|en
SAM|Samoa|OFC|#ce1126|#002b7f|24|en
SOL|Islas Salomón|OFC|#0051ba|#fcd116|34|en
TAH|Tahití|OFC|#ce1126|#ffffff|32|fr
TGA|Tonga|OFC|#c10000|#ffffff|22|en
VAN|Vanuatu|OFC|#d21034|#009543|30|en
"""


def parse():
    out = []
    for line in NATIONS.strip().splitlines():
        c, n, conf, c1, c2, st, pool = line.split("|")
        out.append({"code": c, "name": n, "confed": conf, "c1": c1, "c2": c2, "strength": int(st), "pool": pool})
    return out
