# Retratos ficticios de la demo · 31/10/2026

Generados con la herramienta integrada de ImageGen: una generación separada
por persona. No son fotos de alumnos reales, testimonios ni referencias de
personas conocidas. Los JPEG finales de 384 × 384 están en este directorio:

- `lucia.jpg`: Lucía Vega.
- `dani.jpg`: Dani Torres.
- `nora.jpg`: Nora Martín.
- `marcos.jpg`: Marcos Vidal.

`tools/promo/portrait_data.dart` incorpora estos mismos JPEG como datos de la
entrada de demo, para funcionar también sin red. Ninguna entrada de producto
importa ese archivo; no se han añadido estos retratos a los pubspec de producto.
Los originales de la herramienta se conservan en su carpeta de generación.

## Prompts utilizados

Prefijo común, seguido por el personaje y el sufijo común:

> Use case: photorealistic-natural. Asset type: one fictional athlete profile photograph for an offline fitness app demo. Generate one single square head-and-shoulders portrait, centered face with ample safe room for circular avatar cropping.

Personajes:

- **Lucía:** A Spanish woman around 28 with shoulder length dark brown hair tied back casually, olive skin, brown eyes, black unbranded athletic T-shirt, relaxed confident expression, subtle natural smile.
- **Dani:** A Spanish man around 27 with short brown hair, light stubble, athletic build, grey unbranded athletic T-shirt, relaxed natural smile.
- **Nora:** A Spanish woman around 31 with short curly chestnut hair, freckles, fit build, dark blue unbranded sports T-shirt, friendly composed expression.
- **Marcos:** A Spanish man around 39 with close cropped dark hair and short tidy beard, Mediterranean complexion, olive green unbranded sports T-shirt, friendly composed expression.

Sufijo común:

> Realistic everyday person, realistic skin texture, natural outdoor soft daylight, gently blurred neutral sports facility background. Editorial candid portrait, understated, modern, no glamour retouching, no stock-photo exaggerated expression. This is an entirely fictional person, not a celebrity. No text, letters, badges, logos, watermark, collage or additional people. Produce only this one portrait.
