# Diagrama de Flujo - Sistema de Ratings Eslabón

## Flujo Principal de Ratings

```mermaid
flowchart TD
    A[Usuario solicita ayuda] --> B[Otro usuario ofrece ayuda]
    B --> C[Se acepta la ayuda]
    C --> D[Ayuda completada]
    
    D --> E{¿Quién califica?}
    
    E -->|Solicitante| F[Pantalla: rate_helper_screen.dart]
    E -->|Ayudador| G[Pantalla: rate_offer_screen.dart]
    
    F --> H[Verificar si ya calificó]
    G --> I[Verificar si ya calificó]
    
    H --> J{¿Ya calificó?}
    I --> K{¿Ya calificó?}
    
    J -->|Sí| L[Mostrar mensaje: Ya calificaste]
    K -->|Sí| M[Mostrar mensaje: Ya calificaste]
    
    J -->|No| N[Mostrar interfaz de calificación]
    K -->|No| O[Mostrar interfaz de calificación]
    
    N --> P[Usuario selecciona estrellas y comentario]
    O --> Q[Usuario selecciona estrellas y comentario]
    
    P --> R[Llamar saveRating en firestore_utils.dart]
    Q --> S[Llamar saveRating en firestore_utils.dart]
    
    R --> T[Guardar en colección 'ratings']
    S --> T
    
    T --> U[Trigger: ratingNotificationTrigger.js]
    U --> V[Crear notificación en Firestore]
    V --> W[Enviar notificación FCM]
    
    T --> X[Actualizar promedio del usuario]
    X --> Y[Incrementar helpedCount/receivedHelpCount]
    
    Y --> Z[Rating completado]
    W --> Z
```

## Flujo de Notificaciones

```mermaid
flowchart TD
    A[Rating creado en Firestore] --> B[ratingNotificationTrigger activado]
    
    B --> C[Obtener datos del rating]
    C --> D[Obtener FCM token del usuario calificado]
    
    D --> E{¿Token existe?}
    E -->|No| F[Log warning - No FCM token]
    E -->|Sí| G[Crear notificación en Firestore]
    
    G --> H[users/{userId}/notifications]
    H --> I[createNotificationTrigger activado]
    
    I --> J[Enviar notificación FCM]
    J --> K[Usuario recibe notificación]
    
    K --> L[notification_service.dart procesa]
    L --> M[inapp_notification_service.dart muestra]
```

## Flujo de Deduplicación

```mermaid
flowchart TD
    A[Notificación recibida] --> B[notification_service.dart]
    
    B --> C[Generar dedupeKey]
    C --> D{¿Key en cache?}
    
    D -->|Sí| E[Ignorar notificación duplicada]
    D -->|No| F[Agregar key al cache]
    
    F --> G[Guardar en SharedPreferences]
    G --> H[Mostrar notificación]
    
    H --> I{¿Es chat?}
    I -->|Sí| J[Verificar ventana de 5 segundos]
    I -->|No| K[Mostrar notificación normal]
    
    J --> L{¿Dentro de ventana?}
    L -->|Sí| M[Suprimir notificación]
    L -->|No| N[Mostrar notificación de chat]
```

## Componentes del Sistema

### Frontend (Flutter)
- **rate_helper_screen.dart**: Interfaz para calificar ayudadores
- **rate_offer_screen.dart**: Interfaz para calificar solicitantes  
- **confirm_help_received_screen.dart**: Confirmación de ayuda recibida
- **ratings_screen.dart**: Visualización de ratings
- **ranking_screen.dart**: Ranking de usuarios

### Backend (Firestore)
- **Colección 'ratings'**: Almacena todas las calificaciones
- **firestore_utils.dart**: Lógica de guardado y cálculos
- **notification_service.dart**: Manejo de notificaciones
- **inapp_notification_service.dart**: Notificaciones locales

### Cloud Functions
- **ratingNotificationTrigger.js**: Trigger automático para ratings
- **createNotificationTrigger.js**: Trigger para notificaciones generales
- **sendRatingNotification.js**: HTTP endpoint para ratings manuales

### Esquema de Datos

```json
{
  "ratings": {
    "ratingId": {
      "sourceUserId": "string",
      "ratedUserId": "string", 
      "requestId": "string",
      "rating": "number (1-5)",
      "comment": "string",
      "type": "helper_rating | requester_rating",
      "timestamp": "Timestamp"
    }
  },
  "users": {
    "userId": {
      "averageRating": "number",
      "helpedCount": "number",
      "receivedHelpCount": "number",
      "fcmToken": "string",
      "notifications": {
        "notificationId": {
          "type": "rating_received",
          "title": "string",
          "body": "string", 
          "read": "boolean",
          "timestamp": "Timestamp",
          "data": "object"
        }
      }
    }
  }
}
```