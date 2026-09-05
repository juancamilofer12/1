# R6 VISUAL DESIGN — ZombieSurvival

> Documento de diseño visual independiente. No forma parte del código del proyecto principal, no modifica ningún sistema existente y no debe integrarse todavía. Es una referencia para el equipo de arte/UI y para quien programe cosméticos en fases futuras.

---

## 0. Resumen ejecutivo

- **Tipo de personaje:** R6 exclusivamente. No se contempla R15 en ningún punto del pipeline visual.
- **Estilo:** Roblox clásico reconocible, con identidad de supervivencia/apocalipsis zombie (bosque, peligro, cooperación), sin caer en hiperrealismo.
- **Filosofía cosmética:** todo lo cosmético (skins de personaje, de arma, mochilas, accesorios, efectos) es puramente visual. Cero impacto en daño, precisión, cadencia, alcance, capacidad, velocidad o cualquier stat de gameplay.
- **Rendimiento primero:** cualquier propuesta visual debe ser viable en Roblox con presupuestos de polígonos, partículas y luces conservadores.

---

## 1. Identidad general

El juego debe transmitir, en este orden de prioridad: **peligro → cooperación → exploración → apocalipsis → bosque/naturaleza recuperando terreno**.

Referentes de tono (no de arte 1:1, sino de sensación):
- Campamentos improvisados, ropa civil reforzada con parches y cinta.
- Bosques densos con señales de abandono (barricadas viejas, vehículos volcados, carteles caseros).
- Paleta de "civilización que se apaga": verdes de bosque, marrones de tierra/madera, grises de asfalto y metal oxidado, con acentos de color vivo solo en elementos de utilidad (linternas, vendas, señalización) para que el ojo los encuentre rápido.

**Evitar siempre:**
- Hiperrealismo (texturas PBR ultra detalladas, normal maps agresivos).
- R15, IK avanzado, proporciones anatómicas realistas.
- Diseños que remitan a otro juego reconocible (nada de "clones" de skins de shooters militares AAA).
- Efectos de partículas pesados o permanentes.
- Modelos con demasiados triángulos en accesorios pequeños.

---

## 2. Reglas visuales R6 (obligatorias para todo el contenido)

R6 tiene 6 partes rígidas: Head, Torso, Left Arm, Right Arm, Left Leg, Right Leg. Todo diseño debe partir de esa realidad, no intentar disimularla.

1. **Proporciones clásicas.** Cabeza cúbica/cilíndrica estándar, torso y extremidades en bloques. No estirar ni adelgazar las partes por fuera de los rangos habituales de un personaje R6 estándar (evitar "R6 modificado" tipo bloxy-realista).
2. **Ropa = capas planas sobre bloques.** Camisas, chalecos y pantalones se resuelven con texturas de camisa/pantalón (Shirt/Pants) o con accesorios tipo "Layered Clothing" solo si el proyecto confirma soporte; por defecto, asumir textura clásica de Shirt/Pants + accesorios rígidos, ya que es lo más compatible y ligero.
3. **Accesorios rígidos, no deformables.** Todo objeto (mochila, casco, radio, arma) es una malla rígida anclada a un Attachment/Handle. No se diseñan piezas que dependan de un esqueleto flexible.
4. **Handles pensados para el brazo R6.** Las armas y herramientas se sujetan con una mano en bloque (sin dedos individuales). El diseño de la empuñadura debe verse natural en una mano rectangular: mangos gruesos, sin geometría fina que "flote" en el espacio entre dedos inexistentes.
5. **Mochilas ancladas a Torso Back.** Se diseñan para verse bien sobre un torso rectangular plano; evitar mochilas muy voluminosas que se claven en los brazos al caminar (el ciclo de Walk de R6 balancea los brazos en arco amplio).
6. **Accesorios de cabeza respetan el cuello corto de R6.** Cascos/gorros no deben requerir "cuello" visual; se apoyan directamente sobre la Head.
7. **Poses e idle expresivos con lo mínimo.** Como R6 no tiene dedos ni columna flexible, la expresividad viene de: ángulo de brazos, inclinación de Torso vía animación, y objetos sostenidos (ej. sostener el hacha al hombro en el Idle de leñador).
8. **Nunca diseñar primero para R15.** Cualquier asset debe probarse mentalmente (o físicamente, cuando se produzca) sobre el rig R6 base antes de aprobarse.

---

## 3. Personaje base — "Superviviente estándar"

Este es el esqueleto visual de referencia para todos los personajes futuros (el "default" con el que arranca cualquier jugador nuevo).

- **Concepto:** civil que llevaba días sobreviviendo antes de que empezara la partida. Ropa de calle reforzada de forma improvisada.
- **Colores base:** camisa verde oliva desgastada, pantalón marrón/caqui, botas grises oscuras.
- **Torso:** camisa de manga larga remangada, con un parche de cinta gris en el hombro (simula un remiendo).
- **Piernas:** pantalón cargo con una rodillera improvisada (tela extra) en la pierna derecha.
- **Cabeza:** rostro neutro estándar de Roblox (no forzar una cara única, dejar que el jugador use su propio rostro/Head).
- **Accesorio de cabeza:** ninguno por defecto (slot libre para accesorios).
- **Mochila:** mochila básica de tela, gris/verde, pequeña, sin detalles llamativos — es la "mochila 0", la base de la que derivan todas las mochilas cosméticas.
- **Equipamiento visible:** una cantimplora colgada del cinturón (accesorio pequeño, fijo, no cosmético intercambiable — es parte del personaje base).
- **Sensación deseada:** "alguien común que se las arregla", punto de partida neutro para que cualquier skin se sienta como una mejora/alternativa clara.

---

## 4. Sistema de rarezas

| Rareza | Color identidad | Borde/marco | Iconografía | Exclusividad | Efecto opcional |
|---|---|---|---|---|---|
| Common | Gris (#9E9E9E) | Línea simple 1px | Ninguna | Alta disponibilidad | Ninguno |
| Uncommon | Verde (#4CAF50) | Línea simple 2px | Pequeña hoja/marca de esquina | Disponibilidad media | Ninguno |
| Rare | Azul (#2E86DE) | Doble línea | Esquinas biseladas | Progreso o tienda rotativa | Brillo estático sutil en el icono |
| Epic | Púrpura (#8E44AD) | Marco con textura de "grietas" sutiles | Icono de rombo en la esquina | Logros/desafíos/eventos | Partícula muy tenue al equipar (una vez, no continua) |
| Legendary | Naranja/dorado (#E67E22) | Marco ornamentado con esquinas remachadas | Icono de estrella | Bosses/eventos especiales/ruleta alta | Brillo pulsante lento + partícula ligera continua de bajo costo |
| Mythic | Rojo-violeta con degradado (#C0392B → #6C3483) | Marco animado (degradado que se desplaza lentamente) | Icono de calavera estilizada + estrella | Extremadamente limitada (eventos únicos, hitos de temporada) | Contorno con leve pulso de color + partícula distintiva al moverse (optimizada, baja densidad) |

**Reglas duras:**
- La rareza nunca implica ventaja de gameplay. Se comunica esto explícitamente en la UI ("Solo cosmético") para evitar percepción de pay-to-win.
- Los efectos de rareza alta deben poder desactivarse desde configuración de rendimiento (ver sección 14 y 21).
- El marco/borde es el elemento que más debe leerse a tamaño de icono pequeño (32–48px); el color solo no basta (accesibilidad para daltonismo), por eso cada rareza tiene también una forma de icono distinta.

---

## 5. Skins de personaje (15+)

Formato por skin: nombre — concepto — apariencia — accesorios/mochila — rareza — método de obtención.

1. **Superviviente Gris** — versión "endurecida" del base. Ropa más oscura y remendada, chaleco improvisado de cuero. Mochila básica reforzada con correas extra. — *Common* — Disponible desde el inicio.
2. **Superviviente de Carretera** — ropa de viajero, poncho ligero marrón, botas de trekking. Mochila mediana con rollo de manta atado encima. — *Common* — Tienda rotativa.
3. **Leñador** — camisa a cuadros roja/negra remangada, tirantes, botas de trabajo. Sin mochila (lleva el hacha al hombro por defecto como pose de Idle si tiene hacha equipada). — *Uncommon* — Progreso (nivel de recolección).
4. **Explorador de Bosque** — chaqueta verde bosque con capucha, pantalón de camuflaje forestal, botas altas. Mochila "Explorador" (ver sección 7) integrada visualmente. — *Uncommon* — Desafío de exploración.
5. **Constructor** — mono de trabajo naranja/gris, guantes gruesos visibles como parte de la textura de Right/Left Arm, casco de obra amarillo como accesorio de cabeza. — *Uncommon* — Progreso (nivel de construcción).
6. **Médico de Campo** — chaqueta blanca/roja con cruz simple en el pecho, pantalón gris, brazalete rojo en el brazo. Mochila médica pequeña con parche de cruz. — *Rare* — Desafío de curación/revivir aliados.
7. **Cazador** — chaqueta de camuflaje marrón/verde, capucha con detalle de piel sintética (bajo poli), guantes sin dedos. Mochila con correa para "trofeos" (decorativo, sin función). — *Rare* — Logro de eliminaciones a distancia.
8. **Militar de Reserva** — uniforme verde oliva desgastado, chaleco táctico simplificado (placas planas, no realistas), botas militares. Mochila táctica cuadrada. — *Rare* — Evento temático.
9. **Táctico Urbano** — ropa negra/gris ceniza, rodilleras y coderas visibles como texturas, casco ligero tipo gorra táctica. Mochila compacta negra. — *Epic* — Ruleta o tienda por tiempo limitado.
10. **Superviviente Nocturno** — paleta azul oscuro/negro con detalles reflectantes (franjas claras simuladas en textura, no material emisivo real para ahorrar rendimiento), linterna frontal como accesorio de cabeza. — *Epic* — Evento nocturno/temporada.
11. **Apocalipsis (Harapos y Óxido)** — ropa muy desgastada, remiendos visibles de distintos materiales, cadena decorativa al cinturón, mochila improvisada con chatarra atada. — *Epic* — Boss especial o hito de supervivencia (ej. "sobrevive X oleadas").
12. **Bombero Retirado** — chaqueta ignífuga amarilla/negra desgastada, casco de bombero como accesorio, mochila con manguera enrollada decorativa. — *Rare* — Evento colaborativo.
13. **Ranger de Parque** — uniforme verde institucional, sombrero de ranger (accesorio de cabeza icónico), mochila de campo con mapa enrollado decorativo. — *Uncommon* — Tienda.
14. **Piloto Caído** — mono de vuelo naranja/gris, casco de aviador con gafas subidas a la frente, mochila de emergencia con paracaídas decorativo (plegado, sin animación física). — *Legendary* — Evento de temporada limitado.
15. **Científico de Cuarentena** — traje de bioseguridad simplificado (no hiperrealista: overol amarillo con capucha y visor simple como accesorio de cabeza translúcido), mochila con tanque pequeño decorativo. — *Legendary* — Boss final de fase o logro de historia.
16. **Guardián del Bosque (Especial)** — mezcla de ropa de superviviente con elementos naturales: musgo decorativo en hombro, capucha con ramas estilizadas de baja densidad de polígonos, mochila con detalles de madera tallada. — *Mythic* — Evento único / recompensa de comunidad.
17. **Ceniza Legendaria (Legendary/Mythic showcase)** — outfit completamente en escala de grises con un único acento rojo (bufanda), pensado como "prestige skin" de fin de temporada. — *Mythic* — Pase de temporada, tramo final.

Todas las skins reutilizan el mismo rig y los mismos anclajes que el personaje base (sección 3), cambiando solo texturas de Shirt/Pants y accesorios — esto mantiene el coste de producción bajo y la compatibilidad total con animaciones.

---

## 6. Skins de armas

**Regla dura, repetida a propósito:** ninguna skin de arma altera daño, precisión, cadencia, alcance, capacidad de cargador ni velocidad de recarga real. Solo cambian modelo/textura/efectos/sonido/animación cosmética.

### Pistolas
1. Estándar — metal gris mate, sin desgaste.
2. Oxidada — textura de óxido marrón/naranja, rasguños.
3. Militar — verde oliva mate con cinta de agarre negra.
4. Camuflada — patrón de camuflaje bosque de baja resolución (legible a distancia).
5. Oscura — negro mate total, detalles mínimos, silueta limpia.
6. Especial ("Guardián") — acabado plateado con línea de acento azul, partícula muy sutil al disparar (solo si es Epic+).

### Escopetas
7. Madera — cañón metálico + culata de madera clásica.
8. Oxidada — óxido y desgaste generalizado.
9. Militar — negro/verde con correa táctica decorativa.
10. Táctica — riel superior decorativo (sin función de mira real salvo que el sistema de apuntado ya lo soporte), acabado gris oscuro.
11. Especial ("Trueno") — acabado bronce oscuro con grabados simples geométricos, efecto de disparo con destello ligeramente más grande (cosmético).

### Rifles
12. Militar — verde oliva estándar, correa táctica.
13. Bosque — camuflaje verde/marrón, culata de madera envejecida.
14. Invierno — blanco/gris con detalles azulados, pensado para eventos de temporada fría.
15. Desgastado — negro con abolladuras y cinta improvisada (estética "sobrevivió mucho").
16. Avanzado ("Vanguardia") — líneas más limpias, acentos de color (rojo o cian) sutiles, permitido ser ligeramente más futurista **solo** en esta línea "avanzada", nunca en el resto del set.

Cada skin de arma puede tener, opcionalmente y solo en Epic+: sonido de disparo con una variación tímbrica menor (mismo volumen y timing que el sonido base) y una animación de recarga con un gesto extra (ej. golpe al cargador) que no cambia el tiempo total de recarga.

---

## 7. Mochilas (8+)

| Mochila | Estilo visual | Notas de anclaje R6 |
|---|---|---|
| Básica | Tela gris/verde, pequeña, sin adornos | Anclaje estándar Torso Back, tamaño mínimo |
| Explorador | Verde con correas externas y una cantimplora decorativa atada | Ligeramente más ancha, no debe tocar los brazos en el arco de Walk |
| Militar | Cuadrada, verde oliva, con parche cuadrado | Perfil bajo para no chocar con mochilas + arma a la espalda |
| Médica | Blanca/roja con cruz, forma más redondeada | Tamaño medio, cruz visible desde atrás a distancia |
| Táctica | Negra, compacta, con molle decorativo (líneas, no geometría extra) | La más compacta del set, pensada para skins "Táctico Urbano" |
| Supervivencia | Marrón/verde con manta enrollada encima | Volumen medio-alto, probar que no clipee con capuchas largas |
| Grande ("Expedición") | Voluminosa, con bolsillos laterales y piolet decorativo atado | La más grande permitida; usar solo en skins de exploración/legendarias |
| Legendaria ("Núcleo") | Diseño único por temporada, con acento de color de rareza (dorado/mítico) integrado en las correas | Debe seguir el mismo footprint que "Militar" para evitar problemas de colisión visual con capas |

**Regla de interferencia con armas:** ninguna mochila puede ocupar el mismo espacio visual que el anclaje de arma a la espalda (cuando exista ese sistema). Mantener siempre un margen en la mitad superior del Torso Back libre.

---

## 8. Accesorios (10+)

1. Gorra de superviviente (tela, visera desgastada).
2. Casco de obra (constructor).
3. Casco militar simplificado.
4. Gafas de sol (accesorio de cabeza, no cubre ojos con textura, solo malla).
5. Máscara de tela (cubrebocas improvisado, útil para skins "apocalipsis").
6. Máscara de gas simplificada (para skins de cuarentena/eventos).
7. Radio portátil colgada del hombro (accesorio pequeño, decorativo).
8. Linterna frontal (accesorio de cabeza, sin luz real emitida por defecto para performance; versión "Pro" opcional con luz puntual de bajo costo solo en Epic+).
9. Insignia/parche de tela en el pecho (accesorio plano, casi sin polígonos).
10. Bufanda (accesorio de cuello, ligera variación de color por skin).
11. Guantes sin dedos (aplicados como textura de Arms, no accesorio físico, para no sumar drawcalls).
12. Brazalete de rol (médico/líder de escuadra) — accesorio plano en el brazo.

**Regla anti-saturación:** máximo recomendado por personaje en pantalla = 1 accesorio de cabeza + 1 accesorio de cuello/pecho + mochila + arma. No combinar más de un accesorio "grande" (casco/máscara) a la vez salvo en skins Legendary/Mythic diseñadas específicamente para eso.

---

## 9. Especificación de animaciones R6

Todas las animaciones se diseñan sobre el rig estándar R6 (AnimationId compatible con Motor6D de R6). Duraciones son orientativas para quien produzca los assets.

| Animación | Tipo | Duración orientativa | Notas de diseño |
|---|---|---|---|
| Idle | Loop | 3–4s (variación cada ciclo) | Respiración sutil + micro-movimiento de cabeza; sin sostener nada especial por defecto |
| Walk | Loop | 0.8–1s por paso | Arco de brazos clásico de R6, ligeramente reducido si lleva mochila grande |
| Run | Loop | 0.5–0.6s por paso | Inclinación de Torso hacia adelante vía animación (no física real) |
| Jump | One-shot | 0.3s | Brazos suben ligeramente, piernas se flexionan en el frame de despegue |
| Fall | Loop | — | Brazos abiertos moderadamente, piernas colgando |
| MeleeAttack | One-shot | 0.35–0.5s | Golpe con Right Arm; variante si sostiene hacha (arco más amplio) |
| Shoot | One-shot (por disparo) o loop corto (auto) | 0.1–0.2s por disparo | Retroceso leve del Torso, brazo del arma con leve sacudida |
| Reload | One-shot | 1–2s según arma | Debe leerse claramente desde el punto de vista de otros jugadores (cooperativo = comunicación visual) |
| Equip | One-shot | 0.3s | Mano va al anclaje del arma en la mochila/cinturón y la trae al frente |
| Unequip | One-shot | 0.3s | Inverso de Equip |
| Interact | One-shot | 0.4s | Mano extendida hacia adelante, genérica para botones/objetos |
| Harvest | Loop corto | 0.6–0.8s por golpe | Ver detalle "Talar árbol" y "Picar piedra" abajo |
| Build | Loop corto | 0.5s por "colocación" | Manos al frente como si ajustaran una pieza |
| Repair | Loop corto | 0.6s | Movimiento de martillo/herramienta pequeño y repetitivo |
| Revive | One-shot sostenido | 2–3s (loop mientras se mantiene) | Arrodillado junto al aliado caído, una mano extendida |
| Downed | Loop | — | Personaje semi-tumbado, apoyado en un brazo, cabeza caída |
| Injured | Loop (overlay sobre Walk/Run) | — | Cojera leve: reducir amplitud del paso en la pierna afectada |

### Acciones específicas de recolección/construcción
- **Talar árbol:** variante de MeleeAttack con arco más vertical (de arriba hacia abajo), Right Arm lleva el hacha; sincronizar el "impacto" con el frame más bajo del arco para que el sonido/partícula del hacha en el árbol coincida.
- **Picar piedra:** similar a talar pero arco más horizontal/diagonal, herramienta = pico.
- **Recoger recurso:** agacharse levemente (flexión de Torso y piernas), una mano baja hacia el suelo, vuelve arriba con el objeto "en mano" (el objeto real se resuelve por inventario, la animación solo sugiere el gesto).
- **Abrir caja:** ambas manos al frente empujando/levantando una tapa imaginaria; loop corto de 2–3 repeticiones máximo.
- **Colocar barricada:** variante de Build con ambos brazos empujando hacia adelante (como encajar un tablón).
- **Construir:** ver Build genérico arriba.
- **Reparar:** ver Repair genérico arriba.
- **Usar curación:** una mano va al costado/mochila (simula sacar vendas), luego al torso propio; loop de 1.5–2s.
- **Revivir compañero:** ver Revive arriba; debe ser claramente distinguible de "Downed" para otros jugadores en combate.

**Si no se producen los assets de animación en esta fase:** este cuadro es la documentación completa que el animador necesita: qué animación, tipo (loop/one-shot), duración orientativa y la intención de movimiento. No se requiere generar los archivos `.fbx`/`AnimationId` ahora.

---

## 10. Personalidad expresiva del R6

Con solo 6 partes rígidas, la expresividad viene de:

- **Postura por rol:** el Leñador reposa el hacha en el hombro en Idle; el Médico cruza los brazos ligeramente; el Militar mantiene una postura más erguida.
- **Timing de animación distinto por "peso" de skin:** una skin "Apocalipsis" puede tener un Idle 10–15% más lento/cansado sin tocar el gameplay (nunca reducir la velocidad real de movimiento, solo el timing de la animación cosmética de Idle).
- **Accesorios que reaccionan al movimiento:** una bufanda o correa suelta con un pequeño rig secundario (si el motor de animación del proyecto lo soporta) da vida sin coste alto; si no se soporta, se omite sin problema — no es un requisito duro.
- **Nunca disimular las proporciones R6** intentando estilizar el bloque para que "parezca" R15 con curvas; la personalidad se construye con ropa/pose/animación, no con geometría nueva del cuerpo base.

---

## 11. Estilo visual de armas (identidad de conjunto)

Todas las armas del juego, sin importar la skin, deben leerse como parte del mismo universo:

- **Base:** equipamiento realista moderado, nunca ciencia ficción salvo en la línea "Especial/Avanzada" explícitamente marcada como tal.
- **Formas:** siluetas simples y reconocibles a distancia (importante para lectura rápida en combate cooperativo). Evitar detalles finos que solo se aprecian en primer plano.
- **Materiales sugeridos por textura, no por shaders costosos:** metal mate, madera envejecida, tela/cinta de agarre. Nada de reflejos metálicos costosos ni normal maps de alta frecuencia.
- **Improvisación como tema:** cinta aislante, remaches visibles, piezas claramente reparadas — refuerza el tono de "supervivencia con lo que hay".
- **Excepción controlada:** solo las skins marcadas "Especial" o "Avanzada" (ver listas de armas) pueden tener un acento de color más vivo o una línea ligeramente más futurista, y siempre como excepción puntual, no como tendencia general.

---

## 12. Estilo visual de herramientas

| Herramienta | Estética base | Notas |
|---|---|---|
| Hacha | Cabeza de metal desgastado, mango de madera envuelto en cinta en el punto de agarre | Silueta clara para la animación de talar |
| Pico | Cabeza de metal oxidado, mango largo de madera | Debe distinguirse claramente del hacha en silueta (cabeza puntiaguda vs. filo ancho) |
| Herramienta de reparación | Combinación llave inglesa + cinta/soldador improvisado | Tamaño pequeño, cabe bien en la mano R6 sin verse perdida |
| Multiherramienta | Forma compacta tipo navaja multiusos, con detalles mínimos (no listar cada hoja, solo sugerir la forma) | Es el objeto más pequeño del set — validar que no desaparezca visualmente en la mano |

Todas comparten la misma paleta que el resto del set de armas (sección 11): metal mate + madera/tela, coherencia total de universo.

---

## 13. Cosméticos adicionales (solo diseño, no implementar aún)

- **Títulos:** texto corto bajo el nombre del jugador (ej. "Superviviente de Élite", "Guardián del Bosque"), obtenidos por logros de temporada.
- **Insignias/emblemas:** iconos pequeños junto al nombre en tablas de resultados post-partida.
- **Marcos de perfil:** bordes decorativos para la tarjeta de jugador, siguiendo la misma lógica visual de rarezas (sección 4).
- **Tarjetas de jugador:** fondo temático (bosque, campamento, ruinas) + pose estática del personaje + rareza más alta poseída destacada.
- **Poses de victoria/exhibición:** pequeñas animaciones one-shot para pantalla de resultados, reutilizando el esqueleto de animaciones de combate/rol (sección 9) para no generar trabajo extra.
- **Efectos de eliminación:** un destello o partícula corta y barata al eliminar un zombie especial, ligado a la rareza del arma equipada, nunca ligado a ventaja real.
- **Efectos de equipamiento:** breve partícula al cambiar de arma (solo Epic+), reutilizando el sistema de partículas de rareza ya definido.
- **Efectos de recompensa:** apertura de caja/ruleta con una animación de UI (no de personaje) coherente con el marco de rareza obtenido.

Todo esto se documenta como **backlog de diseño**, no se programa en esta sesión.

---

## 14. Efectos visuales — reglas de contención

- Los efectos cosméticos empiezan a aparecer desde **Epic** en adelante (ver tabla de rareza, sección 4); Common/Uncommon/Rare son puramente geométricos y de textura.
- Ningún efecto es permanente/continuo de alto costo: preferir "un solo disparo" (al equipar, al eliminar, al abrir recompensa) sobre partículas en loop constante.
- Cuando un efecto sí es loop (ej. Mythic), debe usar la menor cantidad de partículas posible (referencia: 3–8 partículas simultáneas, no sistemas densos) y colores planos, sin texturas de partícula pesadas.
- Todo efecto de rareza alta debe tener un toggle de "Efectos reducidos" en configuración (ver sección 15/21) que lo apague sin quitar la skin en sí.

---

## 15. HUD y UI

**Identidad:** R6 + Roblox clásico + supervivencia zombie, priorizando claridad sobre decoración.

- **Paleta UI:** fondos oscuros semitransparentes (gris carbón/verde muy oscuro) con acentos según contexto: rojo para salud/peligro, verde para recursos/naturaleza, ámbar para advertencias (noche, oleada próxima).
- **Tipografía:** fuente robusta, sin serifas, legible a distancia — evitar fuentes decorativas "de fantasía" que rompan el tono Roblox clásico.
- **HUD de juego:**
  - Barra de vida y estamina en esquina inferior izquierda, iconografía simple (corazón/rayo estilizados, no realistas).
  - Slots de inventario rápido en la parte inferior central, con el marco de rareza del ítem equipado visible en el borde del slot.
  - Indicador de estado del grupo (party) simplificado en la esquina superior, reutilizando la lógica de `PartyService`/`PartyUI` ya existente **solo como referencia funcional**, sin tocar ese código.
- **Mochila/Inventario:** grid clásico tipo Roblox, con cada casilla mostrando el marco de rareza correspondiente cuando aplica.
- **Tienda:** secciones por categoría (Personaje / Armas / Mochilas / Accesorios), cada ítem con su marco de rareza, precio y una etiqueta "Solo cosmético" visible.
- **Ruleta:** rueda o grid de recompensas con los colores de rareza de la sección 4; el resultado final se resalta con el marco correspondiente.
- **Selección de personaje:** vista 3/4 del personaje en el centro, paneles laterales para categorías de cosmético (skin, mochila, accesorio, skin de arma).
- **Principio general:** ninguna pantalla debe requerir más de 2 clics para volver al gameplay; toda la UI debe leerse igual de bien en resoluciones pequeñas (accesibilidad móvil, dado que Roblox tiene mucho público mobile).

---

## 16. Iconos

- **Formato base:** ilustración plana simplificada (2–3 tonos por icono), silueta clara reconocible incluso a 32px.
- **Consistencia de ángulo:** armas e herramientas siempre representadas desde el mismo ángulo (3/4 lateral) para que el catálogo se vea uniforme.
- **Color de fondo del icono = color de categoría**, no de rareza (la rareza ya se comunica con el marco exterior, sección 4), para no saturar de información el mismo elemento.
- **Recursos** (madera, piedra, comida, etc.): iconos muy simples, casi pictogramas, para lectura instantánea en HUD.
- **Skins de personaje:** icono = silueta/retrato de busto simplificado, no captura 3D completa, para mantener consistencia visual entre ítems.

---

## 17. Menú de personalización (concepto)

Estructura de pantalla propuesta (solo diseño conceptual, no implementación):

1. **Panel central:** vista del personaje en 3D (o render estático 3/4 si el rendimiento lo exige), con la skin/mochila/accesorios actualmente equipados.
2. **Pestañas superiores:** Personaje | Mochila | Accesorios | Armas.
3. **Grid lateral de opciones** dentro de cada pestaña, cada ítem mostrando:
   - Marco de rareza.
   - Estado: equipado / disponible / bloqueado.
   - Si está bloqueado: icono de método de obtención (candado + tipo: logro, tienda, evento, ruleta).
4. **Filtros:** por rareza (chips seleccionables) y por estado (todo / desbloqueado / bloqueado).
5. **Favoritos:** icono de estrella en la esquina de cada ítem, con una vista "Favoritos" adicional en los filtros.
6. **Info al bloqueado:** al tocar un ítem bloqueado, mostrar un tooltip/panel corto con el método exacto de obtención (ej. "Completa 10 revivals de aliado" o "Disponible en el Evento de Otoño").
7. **Botón de aplicar/equipar** siempre visible y fijo, sin necesidad de scrollear para confirmar el cambio.

---

## 18. Métodos de obtención de cosméticos

- **Progreso:** desbloqueos ligados a estadísticas acumuladas (recolección, construcción, curación, eliminaciones).
- **Logros:** hitos puntuales únicos (ej. "Sobrevive una partida completa sin caer").
- **Desafíos:** objetivos rotativos (diarios/semanales) con recompensas cosméticas menores (Common–Rare).
- **Bosses:** cosméticos Epic/Legendary ligados a derrotar encuentros especiales.
- **Eventos de temporada:** cosméticos temáticos por tiempo limitado, incluyendo piezas Mythic exclusivas de esa temporada.
- **Ruleta:** mezcla ponderada de rarezas (peso alto en Common/Uncommon, peso mínimo en Legendary/Mythic), siempre con las probabilidades visibles si el proyecto decide mostrarlas.
- **Tienda:** rotación de ítems comprables con moneda del juego ganada jugando; opcionalmente también con moneda premium, pero **nunca** como única vía — todo cosmético relevante debe tener también un camino gratuito razonable.
- **Recompensas especiales:** eventos colaborativos de comunidad (ej. hitos globales del servidor).

**Principio rector:** el dinero real puede acelerar u ofrecer variantes exclusivas de presentación, pero el juego debe poder disfrutarse cosméticamente completo sin gastar, y ninguna vía de pago debe tocar gameplay.

---

## 19. Reglas de consistencia (aplican a todo contenido futuro)

1. Toda pieza nueva (personaje, zombie, arma, herramienta, edificio, prop de bosque, UI, efecto) pasa el filtro: *"¿esto se vería como parte de un mismo juego de Roblox de supervivencia zombie, o parece sacado de otro juego?"*
2. Paleta general limitada: verdes de bosque, marrones de tierra/madera, grises de asfalto/metal, con acentos puntuales (rojo peligro, ámbar advertencia, azul utilidad). Nuevas piezas deben encajar en esta paleta salvo excepción justificada (evento especial).
3. Nivel de detalle uniforme: ni un prop híper detallado al lado de bloques simples, ni personajes simples al lado de un edificio hiperrealista. Todo al mismo nivel "Roblox clásico con personalidad".
4. Toda arma/herramienta nueva sigue el criterio de silueta clara a distancia (sección 11).
5. Todo zombie nuevo (cuando se diseñe) debe seguir también base R6 o proporciones compatibles, para mantener coherencia de escala con los jugadores — esto se define en detalle cuando llegue esa fase, no aquí.
6. Toda UI nueva reutiliza los mismos componentes de marco de rareza, tipografía y paleta ya definidos en la sección 15, en vez de crear un lenguaje visual paralelo.
7. Ningún elemento cosmético nuevo puede introducir ventaja de gameplay, sin excepción, sin importar el sistema que lo proponga.

---

## 20. Guía de Creator Store / Free Models

**Regla de oro para todo el equipo:** ningún Free Model se considera seguro por defecto. Todo modelo externo se revisa manualmente antes de tocar el proyecto principal — buscar y eliminar scripts innecesarios, sospechosos, backdoors o cualquier sistema no relacionado con el propósito del modelo, y **jamás incorporarlo automáticamente**.

| Categoría | Términos a buscar | Estilo a elegir | Evitar | Qué revisar antes de usar |
|---|---|---|---|---|
| Árboles | "low poly tree", "stylized forest tree", "pine tree roblox" | Baja densidad de polígonos, colores planos, silueta reconocible | Árboles hiperrealistas con miles de hojas individuales, texturas 4K innecesarias | Conteo de triángulos, si trae scripts (los árboles no deberían traer ninguno), tamaño de textura |
| Casas/estructuras | "cabin low poly", "abandoned house roblox", "wooden shack stylized" | Estructuras simples, techos a dos aguas, madera/chapa envejecida | Interiores hiperdetallados innecesarios si solo se necesita exterior, mansiones fuera de tono | Colisiones correctas, que no incluya scripts de "auto-actualización" u ofuscados, iluminación integrada innecesaria |
| Vehículos | "abandoned car low poly", "rusty truck roblox", "stylized car wreck" | Siluetas simples, óxido/desgaste como textura, sin mecánicas de conducción si no se necesitan | Vehículos con sistemas de manejo/scripts propios si no se van a usar (riesgo y peso innecesario) | Si trae LocalScripts/Scripts embebidos no documentados, número de partes (evitar vehículos con cientos de partes sueltas) |
| Muebles/props de interior | "low poly furniture pack", "post apocalyptic props", "survival camp props" | Formas simples, desgaste sutil, paquetes agrupados por tema | Packs enormes con cientos de props si solo se necesitan unos pocos (usar solo lo necesario) | Licencia de uso, si el modelo requiere plugins/dependencias externas |
| Props generales (barricadas, cajas, escombros) | "barricade roblox model", "debris pack low poly", "wooden crate stylized" | Coherente con la paleta de tierra/madera/metal ya definida | Props con efectos de partículas integrados que no se pueden desactivar | Revisar jerarquía interna en busca de Scripts/ModuleScripts no esperados |
| Armas (solo como referencia de forma, no para usar el script) | "low poly gun model", "stylized rifle mesh roblox" | Solo la malla/textura; el sistema de disparo real debe ser propio del proyecto | Cualquier "kit de arma" que incluya su propio sistema de daño/remotes — **nunca usar la lógica, solo (si acaso) la malla tras revisión** | Extraer únicamamente la malla, eliminar cualquier Script asociado antes de considerar su uso |
| Accesorios/mochilas | "roblox backpack accessory", "survival gear accessory pack" | Compatibles con anclaje R6 estándar, bajo poli | Accesorios con rigs propios incompatibles con Motor6D estándar | Verificar que el accesorio use Attachment estándar (no un sistema propietario del creador) |
| Decoración ambiental | "post apocalyptic decoration pack", "overgrown ruins props" | Vegetación/óxido/musgo sutil sobre estructuras urbanas | Decoraciones con luces dinámicas costosas en exceso | Cantidad de PointLights/SpotLights incluidos, impacto en rendimiento |
| Sonidos | "free sound roblox forest ambience", "footstep sound pack roblox" | Ambientes cortos en loop, efectos cortos y claros | Pistas con derechos poco claros, archivos excesivamente pesados | Licencia/atribución, duración y peso del archivo, si el ID de sonido sigue activo |

**Checklist mínimo antes de aprobar cualquier modelo externo (aplica a todas las categorías):**
1. Abrir el modelo en un entorno aislado, nunca directamente en el juego principal.
2. Revisar toda la jerarquía en busca de `Script`/`LocalScript`/`ModuleScript` no esperados.
3. Eliminar cualquier script que no sea estrictamente necesario para la función visual del modelo (un árbol no necesita scripts; un prop decorativo tampoco).
4. Verificar que no haya `require()` a ubicaciones externas, `HttpService` embebido, ni referencias sospechosas a otros lugares/usuarios.
5. Revisar el conteo de partes/triángulos y el tamaño de texturas frente al presupuesto de rendimiento del juego (sección 21).
6. Confirmar que el anclaje (si es accesorio) sea compatible con R6 estándar antes de dar por buena la pieza.
7. Documentar de dónde salió el modelo (enlace, autor) para trazabilidad, aunque no se integre todavía.

---

## 21. Rendimiento — límites recomendados

- **Partículas:** preferir efectos de un solo disparo; si hay loop, máximo ~3–8 partículas simultáneas por efecto, y solo desde Epic+.
- **Luces:** evitar PointLight/SpotLight en accesorios cosméticos por defecto; si una skin "Pro" los usa (ej. linterna con luz real), debe ser opcional y claramente marcada como de mayor coste.
- **Geometría:** accesorios pequeños (insignias, radios, parches) con la menor cantidad de triángulos posible; reservar algo más de detalle solo para mochilas/cascos que se ven de cerca.
- **Efectos permanentes:** prohibidos como default; todo efecto continuo debe tener toggle de apagado.
- **Texturas:** tamaños moderados, evitar 2K/4K en accesorios pequeños — con 256–512px suele bastar dado el estilo plano/Roblox clásico.
- **Free Models:** cualquier modelo externo se evalúa también bajo estos mismos límites antes de aprobarse (ver checklist sección 20).

**Orden de prioridad cuando haya que elegir:** estilo y claridad primero, personalidad segundo, rendimiento como límite no negociable que nunca se sacrifica por "verse un poco mejor".

---

## 22. Resumen de cantidad de contenido entregado en este documento

- Skins de personaje: **17** (mínimo pedido: 15) — sección 5.
- Skins de armas: **16** entre pistolas, escopetas y rifles (mínimo pedido: 10) — sección 6.
- Mochilas: **8** (mínimo pedido: 8) — sección 7.
- Accesorios: **12** (mínimo pedido: 10) — sección 8.
- Animaciones/acciones especificadas: **17** en la tabla principal + 8 acciones específicas de recolección/construcción detalladas aparte (mínimo pedido: 15) — sección 9.
- Ideas de efectos cosméticos: cubiertas en secciones 13 y 14 (eliminación, equipamiento, recompensa, rareza).

---

## 23. Para el programador principal — resumen de lectura rápida

- El rig es **R6 fijo**, todo accesorio/animación debe validarse contra Motor6D estándar de R6.
- Las skins cambian **solo** Shirt/Pants/accesorios/mallas de arma — nunca stats. Esto simplifica muchísimo la futura implementación: un sistema de cosméticos puede ser puramente de "reemplazo de apariencia" sin tocar el sistema de combate/inventario real.
- La rareza se comunica con **color + forma de marco + icono**, nunca solo color (accesibilidad).
- La UI de personalización (sección 17) está pensada para mapearse 1:1 a un futuro `CosmeticsService`/`CustomizationUI`, pero **ese sistema no existe todavía y este documento no lo crea ni lo integra**.
- La guía de Creator Store (sección 20) incluye un checklist de seguridad que debería aplicarse siempre, incluso a assets fuera del alcance visual (ej. sonidos, props de gameplay).
- Nada en este documento modifica `MatchService`, `PartyService`, `PlayerDataService`, `RemoteService`, `ServiceLoader`, `ConfigurationService`, `CleanupService`, `StateMachine` ni ningún remote existente.

---

*Fin del documento. Archivo nuevo e independiente — no se modificó ningún archivo del proyecto `ZombieSurvival` original.*
