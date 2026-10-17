# DER-Viewer — Universal Interactive Database ERD Platform

Una herramienta web moderna, independiente y sin dependencias de servidor (cero Node runtime, cero bundler) para la **visualización, navegación profunda y auditoría arquitectónica de Diagramas Entidad-Relación (DER / ERD)** generados en Mermaid.

---

## 🌟 Características Principales

* 🔍 **Zoom Focal Infinito (5% al 3500%):** Centrado dinámico con la rueda del ratón en la coordenada exacta del cursor.
* ✋ **Desplazamiento Libre (Pan):** Arrastre de lienzo ultra fluido con aceleración por GPU.
* 🔀 **Drag & Drop de Tablas en Tiempo Real:** Arrastra cualquier tabla para reorganizar la disposición visual a tu gusto. Las líneas de relación (*Foreign Keys*) se recalculan y adaptan elásticamente a 60 FPS con curvas Bezier y etiquetas sincronizadas.
* 🔄 **Restablecimiento Inteligente de Layout:** Botón dedicado y atajo `R` para volver instantáneamente a la disposición original calculada por Mermaid.
* 🔎 **Buscador Dinámico:** Resalta tablas y columnas con brillo cian neón en tiempo real y atenúa el resto del diagrama.
* 🏷️ **Filtros Automáticos de Dominio:** Detecta automáticamente los esquemas (`auth`, `tenants`, `billing`, `projects`, etc.) y genera botones de aislamiento por módulo en la barra superior.
* 📋 **Inspector de Entidades:** Haz clic sobre cualquier tabla para ver su ficha técnica detallada (esquema, tipos de datos, PKs, FKs, UKs) en un panel lateral deslizante.
* 💾 **Exportación Vectorial:**
  * Descarga directa en **SVG Vectorial** limpio y escalable que preserva fielmente cualquier redistribución personalizada de tablas.
  * Copia del código fuente Mermaid al portapapeles con un clic.
* ⚡ **Editor y Carga en Vivo:** Pega cualquier código Mermaid ERD o sube archivos `.mmd` desde la interfaz sin recargar la página.
* 🛡️ **100% Estático y Privado:** Todo el procesamiento ocurre en el navegador local (Client-Side). Ningún dato ni estructura viaja a ningún servidor externo.

---

## 📂 Estructura del Repositorio

```text
der-viewer/
├── index.html                   # Aplicación web completa y autónoma (abrir directamente en navegador)
├── AI_USAGE_GUIDE.md            # Manual de instrucciones para Agentes de IA (extracción y sintaxis)
├── LICENSE                      # Licencia MIT (Open Source, sin restricciones)
├── README.md                    # Documentación principal en español
├── diagrams/                    # Modelos demostrativos y scripts SQL de ejemplo
│   ├── demo_saas_platform.mmd   # Diagrama DER Mermaid: Plataforma Cloud SaaS Multi-tenant (18 tablas)
│   ├── demo_saas_platform.sql   # DDL ejecutable en PostgreSQL con schemas, PKs, FKs y seed data
│   └── demo_ecommerce.mmd       # Diagrama DER Mermaid: Plataforma de Comercio Electrónico
└── scripts/                     # Herramientas de extracción automática desde PostgreSQL
    ├── extract_pg_catalog.sql   # Consulta SQL universal contra information_schema
    ├── extract-pg-der.ps1       # Extractor automatizado para PowerShell (Windows)
    └── extract-pg-der.sh        # Extractor automatizado para Bash (Linux / Contenedores / CI)
```

---

## 🚀 Inicio Rápido

1. Simplemente haz doble clic o abre en tu navegador el archivo `index.html`:
   ```bash
   # En Windows
   start index.html

   # En macOS
   open index.html

   # En Linux
   xdg-open index.html
   ```
2. Explora los modelos demostrativos incluidos en el selector superior:
   * **Demo SaaS Platform (18 tablas):** Arquitectura completa con esquemas `auth`, `tenants`, `billing`, `projects` y `audit`.
   * **Demo E-Commerce (7 tablas):** Esquema típico de comercio electrónico con productos, clientes, pedidos e inventario.
3. Haz clic en **"Cargar / Editar"** para pegar o cargar cualquier diagrama Mermaid propio.

---

## 💾 Base de Datos Demo (SQL)

Si deseas probar el extractor automatizado contra una base de datos real en PostgreSQL, puedes crear instantáneamente el esquema de demostración ejecutando:

```bash
psql -U postgres -d postgres -f diagrams/demo_saas_platform.sql
```

Este script crea 5 esquemas relacionales completos con extensiones UUID, claves foráneas, restricciones de unicidad, columnas JSONB y datos de prueba.

---

## ⌨️ Atajos de Teclado

| Tecla / Acción | Función |
| :--- | :--- |
| **Rueda del Ratón** | Zoom focal hacia / desde la posición del cursor |
| **Click + Arrastrar Canvas** | Desplazar el lienzo (Pan) |
| **Arrastrar Tabla** | Mover y redistribuir tablas en tiempo real con cables dinámicos |
| **Click en Tabla** | Abrir inspector de columnas y restricciones |
| **`R`** | Restablecer la posición de las tablas al layout original |
| **`+` o `=`** | Acercar vista |
| **`-` o `_`** | Alejar vista |
| **`F`** | Auto-ajustar diagrama completo a la pantalla (calculado con tablas movidas) |
| **`0`** | Restablecer vista al 100% |
| **`Escape`** | Cerrar inspector o modal de edición |

---

## 🤖 Uso con Inteligencia Artificial

Para que un asistente de IA (Antigravity, Claude, ChatGPT, Copilot) extraiga automáticamente el DER de cualquier base de datos y lo adapte para este visor, consulta la guía especializada:

👉 **[AI_USAGE_GUIDE.md](./AI_USAGE_GUIDE.md)**

---

## 👥 Créditos y Autores

Esta primera versión de **DER-Viewer** ha sido diseñada y desarrollada conjuntamente por:
* **Reynaldi Sosa** ([@reyss81](https://github.com/reyss81))
* **Gemini 3.8 Flash** (Google DeepMind)

---

## 📄 Licencia

Este proyecto es 100% libre y de código abierto bajo la **Licencia MIT**. Siéntete libre de usarlo, modificarlo y distribuirlo sin ninguna restricción. Consulta el archivo [LICENSE](./LICENSE) para más detalles.
