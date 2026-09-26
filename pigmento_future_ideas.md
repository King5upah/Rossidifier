# Pigmento: Future Vision & Porting Ideas

This document outlines successful concepts from the iOS native implementation that should influence the Flutter Web version, as well as broader conceptual ideas for a potential Version 3.0.

## Ideas to Port to Flutter Web (from iOS)

The recent overhaul of the iOS app introduced several highly successful UX/UI paradigms that should be considered for the web port:

### 1. The "Thick Paper Notebook" Aesthetic
- **Tactility on the Web:** Move away from flat, generic "tech" designs. Implement CSS properties (box-shadow stacking, subtle noise overlays via SVG or CSS, serif typography like 'Playfair Display' or 'Lora') to recreate the physical notebook feel.
- **Warm Ivory Palette:** Abandon stark white and dark modes for a soothing, creative-friendly ivory base background.

### 2. Standalone Processing
- **WebAssembly (Wasm) Integration:** Just as the iOS app dropped the backend for native Swift processing, the Web version should investigate compiling the core C++ or Rust image processing logic (K-Means, Sobel filters) to Wasm. This ensures privacy, reduces server costs, and enables offline capability.
- **Service Workers:** Utilize service workers to handle the heavy image processing off the main UI thread to prevent browser lock-ups.

### 3. The "Scanning" Initialization
- **Visual Feedback:** Implement a similar "scanner" effect (a white glow sweeping across the uploaded image) coupled with a definite progress bar rather than an indefinite spinner. This makes the heavy processing feel premium rather than slow.
- **Direct Canvas Integration:** Allow users to drag-and-drop images directly onto the web canvas.

### 4. Interactive Adjustments
- **Palette Overrides:** The ability to tap an extracted color and override it with a custom hex code/color picker is crucial. The web version should re-run the analysis (via Wasm) instantly when a color is changed.
- **Cumulative Toggle:** Web users should have a floating toggle to switch between isolated layers and an additive "painting progress" view.

---

## Ideas for Pigmento V3.0 (General Evolution)

Looking beyond parity between platforms, Version 3.0 should focus on expanding the utility and creative scope of the application:

### 1. Augmented Reality (AR) Painting Guide
- **Concept:** allow users to view their physical canvas through their device camera, overlaying the generated steps (color regions) directly onto their real-world painting surface.
- **Tech:** ARKit (iOS) / ARCore (Android) / WebXR (Web).

### 2. Brush & Medium Simulation
- **Concept:** Currently, steps are solid blocks of color. V3.0 could simulate different artistic mediums (watercolor wash, thick oil impasto, charcoal hatching) when generating the guide steps to better match the user's intended physical medium.

### 3. Subject-Aware Cropping & Composition
- **Concept:** Before analysis, integrate an ML model that identifies the primary subject (e.g., a face, a pet) and suggests classical composition rules (Rule of Thirds, Golden Ratio) via overlay grids, allowing the user to crop the perfect reference photo before generating the guide.

### 4. Community "Gallery of Steps"
- **Concept:** A social feature within the app where users can share their initial photo, the generated Pigmento guide, and a photo of their final physical painting.
- **Focus:** Building a supportive community of artists learning from each other's color choices.

### 5. Multi-Device "Studio Mode"
- **Concept:** Use the web or iPad version as the primary, persistent display for the reference guide, while using the iPhone as a remote control to flip through steps or adjust the palette without touching the main screen with paint-covered fingers.
