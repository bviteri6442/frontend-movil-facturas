# PuntoVenta — App móvil (Flutter)

Aplicación móvil del sistema de punto de venta / carrito.

| Recurso | URL |
|---------|-----|
| Repositorio | https://github.com/bviteri6442/frontend-movil-facturas |
| API (backend) | https://github.com/bviteri6442/backend-facturas |
| Panel web | https://github.com/bviteri6442/frontend-web-facturas |

Este proyecto **no** se despliega en Railway; se ejecuta en emulador o dispositivo con Flutter.

---

## Requisitos

| Herramienta | Versión |
|-------------|---------|
| Flutter SDK | 3.x (Dart 3.11+) |
| Android Studio / VS Code | Para emulador o dispositivo |
| API PuntoVenta | En ejecución (repo backend) |

---

## Configuración de la API

La URL se define en `lib/config/api_config.dart` o con `--dart-define`.

### Windows / Web / simulador iOS (API en la misma PC)

```dart
// Por defecto en api_config.dart:
http://localhost:56398/api
```

### Emulador Android

`localhost` en el emulador es el propio emulador. Usa la IP especial del host:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:56398/api
```

### Teléfono físico (misma red Wi‑Fi que la PC)

Sustituye por la IP local de tu PC (ej. `192.168.1.50`):

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:56398/api
```

Para ver tu IP en Windows: `ipconfig` → adaptador Wi‑Fi → **IPv4**.

---

## Ejecutar en local

**Terminal 1 — API:**

```powershell
cd ruta\al\backend\PuntoVenta.Api
$env:ASPNETCORE_ENVIRONMENT = "Development"
dotnet run
```

**Terminal 2 — Flutter:**

```powershell
cd ruta\a\frontend-mobile
flutter pub get
flutter run
```

---

## Subir este proyecto a GitHub (primer push)

Ejecuta **dentro de la carpeta `frontend-mobile`**:

```powershell
cd "d:\TRABAJOSCLASES\Proyecto Final\App_Movil_Carrito\frontend-mobile"

git init
git add .
git commit -m "Initial commit: app móvil PuntoVenta Flutter"
git branch -M main
git remote add origin https://github.com/bviteri6442/frontend-movil-facturas.git
git push -u origin main
```

Actualizaciones:

```powershell
git add .
git commit -m "Descripción del cambio"
git push origin main
```

---

## Qué no subir a Git

Ya está en `.gitignore`:

- `build/`
- `.dart_tool/`
- Archivos generados por Flutter/Android/iOS

---

## Estructura

| Ruta | Descripción |
|------|-------------|
| `lib/main.dart` | Entrada de la app |
| `lib/config/api_config.dart` | URL base del API |
| `lib/services/api_service.dart` | Cliente HTTP |
| `pubspec.yaml` | Dependencias Flutter |

---

## Relación con los otros repos

| Repo | Necesario para la app móvil |
|------|----------------------------|
| **backend-facturas** | Sí (API + PostgreSQL) |
| **frontend-web-facturas** | No |
| **frontend-movil-facturas** | Este proyecto |

---

## Credenciales de prueba

Si tu BD tiene los usuarios de demo del backend:

| Correo | Contraseña |
|--------|------------|
| `admin@test.com` | `Password123!` |
