# Instrucciones de cambios requeridos para registros de usuarios

## Objetivo
Unificar el registro de usuarios y clientes para que:
- Todos los que pueden iniciar sesión estén en la tabla `usuarios`.
- Los clientes tengan datos adicionales en la tabla `clientes` (incluyendo saldo).
- El correo sea único en toda la aplicación.
- El rol solo pueda ser cambiado por un administrador.

---

## Cambios en la Base de Datos

### Tabla `usuarios`
- Asegurar que el campo `correo` sea único.
- Agregar campos básicos: `nombre`, `apellido` (si no existen).
- El campo `rol` debe aceptar valores como 'cliente', 'admin', 'vendedor', etc.

### Tabla `clientes`
- Agregar campo `userId` (FK a usuarios.id).
- Agregar campo `saldo` (decimal, default 0).
- Otros datos de cliente: dirección, teléfono, etc.
- Asegurar que solo haya un registro por usuario (userId único en clientes).

---

## Cambios en el Frontend
- El formulario de registro debe pedir:
  - Correo
  - Contraseña
  - Nombre, apellido
  - Datos de cliente (dirección, etc.)
- Al registrar:
  1. Crear usuario en `usuarios` con rol='cliente'.
  2. Crear cliente en `clientes` con userId y saldo inicial.
- El usuario NO puede escoger su rol al registrarse.

---

## Cambios en el Backend
- Validar que el correo no exista en `usuarios` antes de registrar.
- Al registrar usuario con rol 'cliente', crear también el registro en `clientes`.
- Validar que no exista ya un cliente con ese userId.
- El cambio de rol solo lo puede hacer un admin (y debe manejar el registro en clientes si cambia de cliente a otro rol).

---

## Checklist de tareas

| Nº | Tarea                                                                 | Estado |
|----|-----------------------------------------------------------------------|--------|
| 1  | Agregar campo `saldo` a la tabla `clientes`                          | ⬜     |
| 2  | Agregar campo `userId` (FK) a la tabla `clientes`                    | ⬜     |
| 3  | Asegurar que `correo` es único en la tabla `usuarios`                | ⬜     |
| 4  | Modificar formulario de registro para pedir datos de usuario/cliente | ⬜     |
| 5  | Crear usuario con rol 'cliente' y cliente asociado en el backend     | ⬜     |
| 6  | Validar que solo admin puede cambiar roles                            | ⬜     |
| 7  | Validar que solo haya un cliente por usuario                          | ⬜     |
| 8  | Actualizar lógica de login para obtener datos de cliente si aplica    | ⬜     |
| 9  | Probar registro y login de clientes                                   | ⬜     |
| 10 | Documentar cambios y actualizar checklist                             | ⬜     |

---

**Actualiza este archivo conforme avances en el desarrollo.**
