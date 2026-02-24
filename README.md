# 🎨 Rossidifier — De imagen a pintura acrílica, paso a paso

**Rossidifier** es una herramienta web construida con Flutter que analiza cualquier imagen y genera una guía pedagógica paso a paso para pintarla con acrílicos. Sin IA en la nube. Sin APIs. Todo corre en tu navegador.

---

## ✨ ¿Cómo funciona?

Sube una imagen → La app extrae la paleta de colores real → Genera un proceso de 6 etapas con imágenes intermedias simulando cómo un pintor construiría la obra de menor a mayor detalle.

| Etapa | Nombre | Qué hace |
|---|---|---|
| 1 | **Fondo** | Color base dominante, canvas en blanco |
| 2 | **Masa principal** | Manchas grandes sin detalle |
| 3 | **Sombras** | Primera ronda de volumen oscuro |
| 4 | **Luces** | Zonas iluminadas amplias |
| 5 | **Estructura** | Bordes y líneas de contorno |
| 6 | **Detalles finos** | Highlights y microcontraste |

---

## 🧠 El algoritmo de highlights (Etapa 6)

### 🎨 Imagínalo así

Tienes un dibujo con crayones. En el dibujo hay:

- ✨ Partes blancas brillantes en el cabello
- ✨ Luz que golpea la cara
- ✨ Pequeños detalles

Queremos que la computadora encuentre esas partes brillantes y las haga destacar un poco más.

---

### 🟡 Paso 1 — Hacer una versión borrosa

Primero tomamos la imagen y hacemos una copia borrosa.

**¿Por qué?**

Porque cuando algo está borroso, solo ves las formas grandes. No ves los detalles pequeños. Es como entrecerrar los ojos.

---

### 🔵 Paso 2 — Comparar normal vs borroso

Ahora preguntamos:

> "¿Este puntito es más brillante que la versión borrosa a su alrededor?"

Si sí → podría ser un highlight brillante.  
Si no → es color normal.

Buscamos los lugares que son **más brillantes que su entorno**.

---

### 🟢 Paso 3 — Medir la diferencia

Por cada píxel revisamos:

> "¿Qué tan más brillante es este comparado al borroso?"

Si la diferencia es grande → probablemente es detalle.  
Si la diferencia es pequeña → lo ignoramos.

---

### 🔴 El problema que teníamos

En imágenes anime, las partes blancas brillantes del cabello **no son súper brillantes**.

Todo el cabello ya es medio claro. Entonces la parte brillante solo es *un poco* más clara que el resto.

Y la computadora decía:

> "No es suficientemente brillante. Ignorado."

Y se perdían los highlights blancos.

---

### 💡 La solución — Dos ramas de detección

**Rama A — High-Frequency (Microcontraste):**  
Detecta zonas que son notablemente más brillantes que su entorno inmediato usando la magnitud vectorial RGB: `√(ΔR² + ΔG² + ΔB²)` con un threshold adaptativo basado en `mean + 1.2 * σ`.

**Rama B — Bright Flat Regions (Highlights planos):**  
Para las zonas que ya son globalmente brillantes pero no tienen contraste fuerte con su vecindario (como los mechones blancos en cabello claro). Usamos luminancia perceptual real `0.299R + 0.587G + 0.114B` comparada contra `globalMean + 0.8 * σ`.

---

### 🎨 ¿Qué pasa al final?

Cuando encontramos un highlight:

No lo pintamos de blanco puro (eso se vería horrible). Solo lo hacemos **un poco más brillante** — como agregar un toque suave de pintura más clara encima.

---

### 📦 Resumen super simple

El algoritmo:

1. Hace una copia borrosa.
2. Busca puntos más brillantes que su entorno.
3. También busca puntos que ya son muy brillantes en general.
4. Hace esos puntos un poco más brillantes.

Y así es como aparece el cabello blanco brillante. ✨

---

## 🛠 Stack técnico

- **Flutter Web** — UI y orquestación
- **`package:image`** — Procesamiento de imagen en el cliente (K-Means, Sobel, Gaussian Blur)
- **`package:file_picker`** — Selección de archivos
- **MVVM** — `GuideViewModel` con `ChangeNotifier` + `ListenableBuilder`
- **Web Workers (via `compute`)** — Procesamiento en isolate separado

## 🚀 Correr localmente

```bash
git clone https://github.com/rodocatepetl/Rossidifier
cd Rossidifier
flutter pub get
flutter run -d chrome
```

## 📄 Licencia

MIT
