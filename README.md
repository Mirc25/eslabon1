# eslabon

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
## Moderación E2E (Texto, Imágenes, Videos)

Objetivo: UI solo renderiza contenido `approved`, sin romper flujos existentes.

### Storage (estructura)
- Rutas: `pending/*`, `public/*`, `quarantine/*`, `rejected/*`.
- El cliente SIEMPRE sube a `pending/{tipo}/{uid}/...` con metadata `docPath` apuntando al documento en Firestore.
- Reglas: lectura pública solo en `public/*` (ver `storage.rules`). `pending/*` lectura/escritura solo para el dueño. `quarantine/*` y `rejected/*` son gestionadas por Functions.

### Cloud Functions
- `moderateImageUpload`: al finalizar upload en `pending/images/**`, evalúa SafeSearch (adult/racy/violence/medical/spoof). Mueve a:
  - `public/` → `approved`
  - `quarantine/` → `manual_review`
  - `rejected/` → `rejected`
  Actualiza `moderation.status` en el doc (`metadata.docPath`).
- `moderateVideoUpload`: igual criterio para videos. Si hay `metadata.thumbnailPath` (.jpg/.png), se modera; si no, `manual_review` por defecto.
- `moderateTextAndSet` (HTTPS callable): recibe `{ docPath, text }`, evalúa con Perspective y setea `moderation.status` en el doc.
- Configuración de umbrales desde `config/moderation` (Firestore) o variables de entorno.

### Firestore (bandera de moderación)
- Cada doc con media o texto tiene `moderation.status` en `{ approved | manual_review | rejected | pending }`.
- No se borra contenido; solo se marca estado y se mueve el archivo en Storage.

### App (cliente)
- Uploader: usa `AppServices.uploadPendingMedia(...)` para subir a `pending/*` con metadata `docPath`. Marca `status=pending` en el doc.
- UI: renderiza solo si `moderation.status == 'approved'`. Helper: `ModerationUtils.onlyApproved(query)`.
- Dueño: si `pending`, mostrar “En revisión”. Si `rejected`, ocultar o rotular según UX.
- Reportar: botón que llama `AppServices.createReport(...)` y crea `/reports`.
- Streams: UI escucha el doc y cambia automáticamente cuando pasa a `approved`.

### Seguridad y performance
- App Check: activado en `main.dart` (debug: proveedor de pruebas; release: Play Integrity/App Attest).
- Storage: lectura pública solo en `public/*` (reglas actualizadas).
- Functions y Bucket en misma región (ajustar `region` de las funciones si el proyecto usa otra región). Opcional: `minInstances=1` para evitar cold starts.

### Configuración y umbrales
- Umbrales por defecto (pueden sobrescribirse en `config/moderation.thresholds`):
  - SafeSearch: `adult/racy >= LIKELY → rejected`; `violence/medical >= LIKELY → manual_review`; `spoof >= POSSIBLE → manual_review`.
  - Perspective: `toxicity ≥ 0.82 → manual_review`; `sex ≥ 0.75 → rejected`; `hate ≥ 0.75 → manual_review`.
- Clave del proveedor de texto (Perspective) en `config/moderation.perspectiveApiKey` o variable de entorno `PERSPECTIVE_API_KEY`.

### QA rápido
- Imagen normal → `approved` → se publica sola.
- Imagen XXX → `rejected` → no se muestra.
- Violenta → `manual_review` → no se muestra.
- Mensaje ofensivo → `rejected/manual_review` según umbrales.
- Video con thumbnail limpio → `approved`; sin thumbnail → `manual_review`.

### Entregables
- Estructura de Storage aplicada (`storage.rules`).
- Functions activas: `moderateImageUpload`, `moderateVideoUpload`, `moderateTextAndSet`.
- UI filtrando por `moderation.status` (utilidades en `lib/utils/firestore_utils.dart`).
- Documentación de rutas, umbrales, dónde se setea `docPath` y cómo reportar contenido.
