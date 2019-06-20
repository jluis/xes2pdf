## Generación y analisis de PDF en Perl
twitter:@jluis10
github:@jluis
---
<!-- .slide: data-background="survey.jpg" -->

# Escenario de trabajo
## Administracion Publica
### Unidad de inspeccion i sanciones
* 100.000 Notificaciones (papel/digital)
  * 40.000 Firmas Electronicas
  * 20.000 envios digitales i justificantes
---
# Herramientas proporcionadas
## Windows 8.1 Pro
 * Imposibilidad de instalar programass
 * Limitado a soluciones portables
---
# Windows 8.1 Pro
## herramientas instaladas para PDFs
* Adobe Acrobat
* browser's plugins
* OpenOffice 4.1.2
* LibreOffice 4.1.3.2
* PDFCreator 
* Office 14.
___
## herramientas portables usadas
* cigwin (MobaXTerm)
 * acceso al tollbox *nix para PDF 
* [Strawberry Perl](http://strawberryperl.com/)
 * ¿[berrybrew](https://github.com/dnmfarrell/berrybrew)?
---
# *nix tools
* TeX
* [Ghostscript](http://git.ghostscript.com/)
* [poppler-utils](https://poppler.freedesktop.org/)
* [imageMagic](https://imagemagick.org/index.php)
---
# Strawberry Perl
"When I'm on Windows, I use Strawberry Perl""
  -- Larry Wall
* PDF::API2
* CAM::PDF
* ~~PDF::CreateSimple~~
* PDF::Create
* ~~PDF::Haru~~
* ~~Poppler~~
* [CPAN](https://metacpan.org/search?q=pdf)
---
# CAM::PDF
* Analisis y Moificacion de Pdfs
* Extraccion de adjuntos
* Alternatives Poppler
---
# PDF::API2
* Creacion y moificacion de Pdfs
* PDF::API2::Lite
* PDF::API2::Simple
---
# Demo
[PDF::API2::SIMPLE](https://metacpan.org/pod/PDF::API2::Simple)

[CAM::PDF](https://www.pdfscripting.com/public/Free-Sample-PDF-Files-with-scripts.cfm)
___
# ¿Preguntas?
___
#Gracias por venir
<!-- .slide: data-background="end.jpg" -->
