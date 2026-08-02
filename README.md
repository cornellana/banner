# Banner

App de iPhone y iPad que convierte la pantalla en un rótulo luminoso: escribes un
mensaje (con emoticonos si quieres), eliges color, tipografía, tamaño y velocidad
con deslizadores, y el texto recorre la pantalla en apaisado ocupando toda su
anchura.

## Qué hace

- **Mensaje**: cualquier texto, emoticonos incluidos, **con formato por tramos**.
  Al seleccionar texto aparece *Formato* en el menú de iOS (negrita, cursiva,
  subrayado) y la barra sobre el teclado añade el color, de modo que un mismo
  mensaje puede llevar varios colores.
- **Tipografía**: catorce tipos, desde los diseños del sistema (redondeada, con
  remates, monoespaciada) hasta Futura, Marker Felt o Snell Roundhand.
- **Color del texto**: tono, saturación y brillo con tres deslizadores.
- **Fondo**: los mismos tres deslizadores; con el brillo a cero queda negro, que
  es el valor por defecto.
- **Trayectoria**: un lienzo tipo firma donde se dibuja con el dedo el recorrido
  (o se elige onda, sierra o recta); las letras suben y bajan siguiéndolo
  mientras cruzan la pantalla. El trazo se repite a lo largo del recorrido.
- **Velocidad**: de 40 a 1600 puntos por segundo.
- **Tamaño**: proporción de la altura de la pantalla que ocupa el texto.
- **Destellos**: el fondo parpadea en el color elegido para llamar la atención.
  Se encienden y apagan con **los botones de volumen** mientras el rótulo está en
  pantalla, sin tocar nada: se observa el volumen de salida de la sesión de audio
  (iOS no entrega los botones como eventos salvo a apps de captura) y se recentra
  al llegar a los extremos para que el gesto se pueda repetir.
- **Pantalla externa**: al conectar un televisor por AirPlay, un monitor por
  cable o un iPad como pantalla, el rótulo se muestra allí a pantalla completa
  mediante una escena de rol *external display* — igual que hacen las apps de
  vídeo, no es un simple duplicado. El iPhone sigue mostrando los ajustes y todo
  lo que se toca se refleja al instante en la pantalla grande.
- **Mensajes guardados**: el icono de guardar conserva el mensaje con todas sus
  características, y el de la pila abre una biblioteca con la vista previa real
  de cada uno; al tocar una se cargan sus ajustes. Se borran con una pulsación
  larga. Se guardan en un JSON dentro del directorio de soporte de la app.
- **Salir en cualquier momento**: un toque muestra la barra con el botón
  *Ajustes*; dos toques o un deslizamiento vertical vuelven directamente a la
  pantalla de configuración.

La pantalla no se apaga mientras el rótulo está en marcha y la app gira sola a
apaisado al mostrarlo.

## Compilar

```bash
xcodegen generate
xcodebuild build -project Banner.xcodeproj -scheme Banner \
  -destination 'generic/platform=iOS Simulator'
open Banner.xcodeproj
```

Requiere iOS 17.0 o posterior. El icono se regenera con:

```bash
swift scripts/render_icon.swift Banner/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Idiomas

Inglés, español y catalán (`Localizable.xcstrings`). El idioma se elige **dentro
de la app**, en la sección *Idioma* de los ajustes, sin pasar por los ajustes del
sistema y sin reiniciar: la selección se aplica inyectando su `Locale` en el
entorno de SwiftUI, contra el que se resuelven los textos en cada dibujado. La
opción *Automático* sigue al idioma del sistema.
