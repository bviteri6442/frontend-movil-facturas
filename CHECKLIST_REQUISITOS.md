# Checklist de requisitos - App Carrito de Compras

| Nº  | Requisito (resumido)                                               | Estado         |
|-----|--------------------------------------------------------------------|----------------|
| 1   | Modelo entidad-relación normalizado                                | ✔ (asumido)    |
| 2   | Login seguro y registro de usuario                                 | ✔              |
| 3   | Carrito de compras con tablas/campos lógicos                       | ✔ (modelo/lógica) |
| 4   | Un producto solo una vez en el carrito                             | ✔              |
| 5   | Calcular totales, subtotales, IVA                                  | ✔ (en modelo)  |
| 6   | Editar solo campos necesarios                                      | 🟡 (falta UI)  |
| 7   | Validar todos los campos en formularios                            | ✔              |
| 8   | Disminución automática de inventario                               | 🟡 (falta integración con backend) |
| 9   | Mostrar solo productos con stock > 0 y activos                     | ✔              |
| 10  | No permitir comprar más de lo que hay en stock                     | ✔ (en modelo)  |
| 11  | Permitir eliminar producto del carrito antes de guardar            | ✔ (en modelo)  |
| 12  | Permitir editar producto/cantidad en carrito antes de guardar      | ✔ (en modelo)  |
| 13  | Listar compras del usuario actual y ver detalle                    | ✖              |
| 14  | UI usable y fácil de usar                                          | 🟡 (falta pulir)|
| 15  | Validaciones, mensajes personalizados, almacenar errores           | 🟡             |
| 16  | Programación por capas (Clean Architecture)                        | ✔              |
| 17  | Consumir solo servicios REST del backend                           | ✔              |
| 18  | Seguridad JWT                                                      | ✔              |
| 19  | Base de datos remota y compartida con web                          | ✔              |
| 20  | Backend publicado en la nube (no la BD, solo backend)              | 🟡 (falta publicar) |
|     | Imágenes de productos (campo en BD, CRUD en web, mostrar en móvil) | ✖              |
|     | Gestión de perfil de usuario (CRUD, foto, solo su propio perfil)   | ✖              |


**Leyenda:**
- ✔ = Listo
- 🟡 = Parcial/en progreso
- ✖ = Falta

Actualiza este archivo conforme avances en el desarrollo.
