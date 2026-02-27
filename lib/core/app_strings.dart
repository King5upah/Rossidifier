// ─── AppStrings — All UI copy in EN and ES ────────────────────────────────
enum AppLang { en, es }

class AppStrings {
  final AppLang lang;
  const AppStrings(this.lang);

  bool get isEn => lang == AppLang.en;

  // ── Header ───────────────────────────────────────────────────────────────
  String get appTitle => 'Rossidifier';
  String get appSubtitle => isEn
      ? 'From image to acrylic painting, step by step.'
      : 'De imagen a pintura acrílica, paso a paso.';

  // ── Upload section ────────────────────────────────────────────────────────
  String get uploadPrompt    => isEn ? 'Select an image'     : 'Selecciona una imagen';
  String get uploadHint      => isEn ? 'JPG or PNG • Max 50MB' : 'JPG o PNG • Máx 50MB';
  String get changeImage     => isEn ? 'Change image'        : 'Cambiar imagen';

  // ── Confirmation Dialog ───────────────────────────────────────────────────
  String get confirmChangeTitle => isEn ? 'Change Image?' : '¿Cambiar imagen?';
  String get confirmChangeDesc  => isEn ? 'Are you sure you want to discard the current image and start over?' : '¿Estás seguro que deseas descartar la imagen actual y comenzar de nuevo?';
  String get confirmYes         => isEn ? 'Yes, change it' : 'Sí, cambiarla';
  String get confirmCancel      => isEn ? 'Cancel' : 'Cancelar';

  // ── Demo row ────────────────────────────────────────────────────────────
  String get demoLabel       => isEn ? 'Or try a demo'       : 'O prueba una demo';
  String get demoAnime       => isEn ? 'Figure'              : 'Figura';
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
  String get errorTooLarge   => isEn ? 'Image exceeds the 50MB limit.' : 'La imagen excede el límite de 50MB.';
  String get errorGeneral    => isEn ? 'Error analysing the image. It may be too large or corrupt.' : 'Error al analizar la imagen. Quizá sea muy grande o corrupta.';
  String get errorDemoLoad   => isEn ? 'Could not load the demo image.' : 'No se pudo cargar la imagen demo.';

  // ── Tap-to-view ────────────────────────────────────────────────────────
  String get tapToView       => isEn ? 'Tap to expand'       : 'Toca para ver';

  // ── Tabs ────────────────────────────────────────────────────────────────
  String get tabSnapshot    => isEn ? 'Snapshot'            : 'Instantánea';
  String get tabCumulative  => isEn ? 'Layered'             : 'Capas';
  String get tabMath        => isEn ? 'About/Engineering'   : 'Acerca de/Ingeniería';

  // ── Render mode descriptions (moved inside the tabs or math page) ──────
  String get modeDescSnapshot    => isEn
      ? 'Each image shows the target appearance at that stage of detail.'
      : 'Cada imagen muestra el aspecto objetivo en esa etapa de detalle.';
  String get modeDescCumulative  => isEn
      ? 'Each image builds on the previous — like paint layers on a real canvas.'
      : 'Cada imagen construye sobre la anterior — como capas de pintura en un lienzo real.';

  String get mathIntroTitle => isEn ? 'The Engineering Behind Rossidifier' : 'La Ingeniería Detrás de Rossidifier';
  String get mathIntroDesc  => isEn 
      ? 'Rossidifier strips away the complexity of a photograph to emulate the human cognitive process of painting. Instead of applying basic filters, it uses unsupervised machine learning, edge detection convolutions, and frequency separation to calculate structural masses just like a master painter dissects a subject.' 
      : 'Rossidifier elimina la complejidad de una fotografía para emular el proceso cognitivo humano de pintar. En lugar de aplicar filtros básicos, utiliza aprendizaje automático no supervisado, convoluciones de detección de bordes y separación de frecuencias para calcular masas estructurales tal como un maestro pintor disecciona un sujeto.';
  String get mathStep1Title => isEn ? '1. Color Quantization (K-Means Clustering)' : '1. Cuantización de Color (Agrupamiento K-Means)';
  String get mathStep1Desc  => isEn 
      ? 'The image is drastically simplified via a K-Means iterative algorithm. Every pixel is plotted in a 3D RGB color space. The algorithm identifies the N most dominant "centroids" (the underlying palette) and shifts all surrounding gradients to their nearest centroid. This creates the flat, blocked-in foundation.'
      : 'La imagen se simplifica drásticamente mediante un algoritmo iterativo K-Means. Cada píxel se traza en un espacio de color RGB 3D. El algoritmo identifica los N "centroides" más dominantes (la paleta subyacente) y desplaza todos los gradientes circundantes a su centroide más cercano. Esto crea la base plana y bloqueada.';
  String get mathStep2Title => isEn ? '2. Structure mapping (Sobel Operator)' : '2. Mapeo de Estructura (Operador Sobel)';
  String get mathStep2Desc  => isEn 
      ? 'To construct the drawing logic, the engine generates a luminosity map. We then apply a discrete differentiation operator (Sobel kernel) via matrix convolution. Areas with a high gradient magnitude become structural lines, highlighting major planes and facial contours.'
      : 'Para construir la lógica de dibujo, el motor genera un mapa de luminosidad. Luego aplicamos un operador de diferenciación discreta (núcleo de Sobel) mediante convolución de matrices. Las áreas con una alta magnitud de gradiente se convierten en líneas estructurales, resaltando los planos principales y contornos faciales.';
  String get mathStep3Title => isEn ? '3. High-Frequency Micro-Contrast' : '3. Micro-Contraste de Alta Frecuencia';
  String get mathStep3Desc  => isEn 
      ? 'The final pass involves Unsharp Masking mathematics to extract pure details. We subtract a heavily blurred (Gaussian) matrix from the sharp original matrix. We then apply a conditional threshold, painting only the pixels whose luminance significantly deviates from their local baseline. This perfectly captures specular highlights, thin hair, and sharp textures.'
      : 'El paso final implica matemáticas de Unsharp Masking para extraer detalles puros. Restamos una matriz fuertemente desenfocada (Gaussiana) de la matriz original nítida. Luego aplicamos un umbral condicional, pintando solo los píxeles cuya luminancia se desvía significativamente de su línea base local. Esto captura perfectamente los brillos especulares, cabello fino y texturas nítidas.';

  // ── GIF Export ────────────────────────────────────────────────────────────
  String get gifDownload  => isEn ? 'Download Animation (GIF)' : 'Descargar Animación (GIF)';
  String get gifEncoding  => isEn ? 'Encoding GIF…'            : 'Codificando GIF…';

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
