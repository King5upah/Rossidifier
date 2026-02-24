// ─── AppStrings — All UI copy in EN and ES ────────────────────────────────
enum AppLang { en, es }

class AppStrings {
  final AppLang lang;
  const AppStrings(this.lang);

  bool get isEn => lang == AppLang.en;

  // ── Header ───────────────────────────────────────────────────────────────
  String get appTitle => 'PaintGuide';
  String get appSubtitle => isEn
      ? 'From image to acrylic painting, step by step.'
      : 'De imagen a pintura acrílica, paso a paso.';

  // ── Upload section ────────────────────────────────────────────────────────
  String get uploadPrompt    => isEn ? 'Select an image'     : 'Selecciona una imagen';
  String get uploadHint      => isEn ? 'JPG or PNG • Max 10MB' : 'JPG o PNG • Máx 10MB';
  String get changeImage     => isEn ? 'Change image'        : 'Cambiar imagen';

  // ── Demo row ────────────────────────────────────────────────────────────
  String get demoLabel       => isEn ? 'Or try a demo'       : 'O prueba una demo';
  String get demoAnime       => isEn ? 'Anime figure'        : 'Figura anime';
  String get demoMexico      => isEn ? 'Angel of Independence': 'Ángel de la Independencia';
  String get demoSeattle     => isEn ? 'Seattle at sunrise'  : 'Seattle al amanecer';

  // ── Results section ───────────────────────────────────────────────────────
  String get paletteTitle    => isEn ? 'Your Palette'        : 'Tu Paleta';
  String get guideTitle      => isEn ? 'Step-by-Step Strategy': 'Estrategia Paso a Paso';

  // ── Loading overlay ───────────────────────────────────────────────────────
  String get loadingTitle    => isEn ? 'Processing'          : 'Procesando';
  String get loadingSubtitle => isEn
      ? 'Extracting colors and calculating structure.'
      : 'Extrayendo colores y calculando estructura.';

  // ── Errors ────────────────────────────────────────────────────────────────
  String get errorNoRead     => isEn ? 'Could not read the image.' : 'No se pudo leer la imagen.';
  String get errorTooLarge   => isEn ? 'Image exceeds the 10MB limit.' : 'La imagen excede el límite de 10MB.';
  String get errorGeneral    => isEn ? 'Error analysing the image. It may be too large or corrupt.' : 'Error al analizar la imagen. Quizá sea muy grande o corrupta.';
  String get errorDemoLoad   => isEn ? 'Could not load the demo image.' : 'No se pudo cargar la imagen demo.';

  // ── Tap-to-view ────────────────────────────────────────────────────────
  String get tapToView       => isEn ? 'Tap to expand'       : 'Toca para ver';

  // ── Render mode toggle ─────────────────────────────────────────────────
  String get modeSnapshot    => isEn ? 'Snapshot'            : 'Instantánea';
  String get modeCumulative  => isEn ? 'Layered'             : 'Capas';
  String get modeDescSnapshot    => isEn
      ? 'Each image shows the target appearance at that stage of detail.'
      : 'Cada imagen muestra el aspecto objetivo en esa etapa de detalle.';
  String get modeDescCumulative  => isEn
      ? 'Each image builds on the previous — like paint layers on a real canvas.'
      : 'Cada imagen construye sobre la anterior — como capas de pintura en un lienzo real.';

  // ── GIF Export ────────────────────────────────────────────────────────────
  String get gifDownload  => isEn ? 'Download GIF' : 'Descargar GIF';
  String get gifEncoding  => isEn ? 'Encoding…'    : 'Codificando…';

  // ── Painting steps ───────────────────────────────────────────────────────
  String stepTitle(StepKey key) {
    switch (key) {
      case StepKey.background:
        return isEn ? 'Background'     : 'Fondo';
      case StepKey.mainMass:
        return isEn ? 'Main Shape'     : 'Masa principal';
      case StepKey.shadows:
        return isEn ? 'Volume & Shadows': 'Volumen y Sombras';
      case StepKey.lights:
        return isEn ? 'Lights'         : 'Luces';
      case StepKey.structure:
        return isEn ? 'Structure'      : 'Estructura';
      case StepKey.details:
        return isEn ? 'Fine Details'   : 'Detalles finos';
    }
  }

  String stepDesc(StepKey key, {String? lightDir, String? lightOpp}) {
    switch (key) {
      case StepKey.background:
        return isEn
            ? 'Apply the base color all over the canvas as a flat block. Don\'t worry about shapes or detail — just cover the surface.'
            : 'Aplica el color base sobre todo el lienzo. Usa un bloque plano, sin atender formas. Solo trata de manchar toda la superficie.';
      case StepKey.mainMass:
        return isEn
            ? 'Focus only on the overall silhouette of the subject. Avoid eyes, hair, or any internal detail. Paint the mass as one large flat shadow.'
            : 'Fíjate solo en la silueta general. Evita ojos, cabello o detalles internos. Pinta la masa como una sola mancha grande.';
      case StepKey.shadows:
        return isEn
            ? 'Build up volume by adding dark areas, mainly on the ${lightOpp ?? "shadow side"}. Keep working with broad strokes.'
            : 'Construye el volumen añadiendo zonas oscuras, principalmente en el lado ${lightOpp ?? "de sombra"}. Sigue con manchas amplias.';
      case StepKey.lights:
        return isEn
            ? 'Highlight the zones where light hits (coming from the ${lightDir ?? "light side"}). Gradually give the subject dimensionality.'
            : 'Resalta las zonas donde pega la luz (desde el lado ${lightDir ?? "iluminado"}). Poco a poco da tridimensionalidad al sujeto.';
      case StepKey.structure:
        return isEn
            ? 'Define planes, mark important edges, facial contours, and separate large shapes with subtle lines.'
            : 'Define planos, marca bordes importantes, contornos faciales y separa formas grandes con líneas tenues.';
      case StepKey.details:
        return isEn
            ? 'Finally use thin brushes to add micro-details, fine textures, specular highlights, and sharp contrasts.'
            : 'Finalmente usa pinceles delgados para agregar micro detalles, texturas finas, brillos puntuales y contrastes marcados.';
    }
  }

  // ── Light direction labels ──────────────────────────────────────────────
  String lightDirLabel(String dir) {
    if (!isEn) return dir; // Already Spanish from generator
    const map = {
      'superior izquierda': 'top-left',
      'superior derecha':   'top-right',
      'inferior izquierda': 'bottom-left',
      'inferior derecha':   'bottom-right',
      'opuesto a la luz principal': 'opposite the main light',
    };
    return map[dir] ?? dir;
  }
}

enum StepKey { background, mainMass, shadows, lights, structure, details }
