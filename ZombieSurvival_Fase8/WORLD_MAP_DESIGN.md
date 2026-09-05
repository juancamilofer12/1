# WORLD MAP DESIGN — ZombieSurvival

> Documento de diseño independiente. No modifica ningún archivo del proyecto principal ni implementa gameplay. Sigue la identidad visual definida en `R6_VISUAL_DESIGN.md` (Roblox clásico + R6 + supervivencia zombie + apocalipsis de bosque).

---

## 0. Resumen ejecutivo

- **Mapa principal:** "El Claro Cercado" (nombre de trabajo) — un valle boscoso con un pueblo/campamento central en decadencia, rodeado de bosque denso, carreteras rotas y zonas periféricas de mayor riesgo/recompensa.
- **Bucle de juego que el mapa debe fomentar:** explorar → recolectar → volver a la base → prepararse → defenderse → sobrevivir. Todo el layout está pensado para que ese bucle sea corto al principio (zona central) y se alargue/arriesgue a medida que el jugador se aventura hacia los anillos exteriores.
- **Filosofía de spawns de zombies:** nunca sobre el jugador ni dentro de su campo de visión inmediato; siempre desde puntos fijos o de borde de zona, con aviso ambiental previo cuando sea posible (sonidos, niebla más densa, etc.).

---

## 1. Estructura general — el mapa en anillos

Pensar el mapa como **3 anillos concéntricos** alrededor de un punto central seguro, no como una cuadrícula homogénea. Esto refuerza visualmente el bucle explorar→volver a la base.

1. **Anillo 0 — Campamento Central (zona segura/base).** El punto de partida de la partida. Terreno abierto y despejado, visibilidad alta, sin árboles densos cerca. Aquí es donde se recomienda construir.
2. **Anillo 1 — Bosque Cercano y Pueblo Abandonado.** Primera zona de exploración: riesgo bajo-medio, recursos básicos, loot común/uncommon, casas abandonadas fáciles de registrar.
3. **Anillo 2 — Bosque Profundo, Carretera y Zonas Industriales.** Riesgo medio-alto, loot rare/epic, vehículos, rutas más largas y menos vigiladas.
4. **Anillo 3 — Periferia Peligrosa (pantano, cantera, instalación militar en ruinas).** Riesgo alto, loot legendary/mythic, posibles zonas de boss, secretos.

La distancia entre anillos también regula la dificultad de "volver a la base": cuanto más lejos se aventura el jugador, más zombies y menos rutas seguras de regreso, lo cual empuja naturalmente a preparar expediciones en vez de improvisar.

---

## 2. Zonas principales

### 2.1 Campamento Central (Anillo 0)
- Claro abierto rodeado por una valla perimetral rota en varios puntos (reparable narrativamente, aunque la reparación real de estructuras sea un sistema de gameplay futuro).
- Terreno llano, ideal para construir base — ver sección 6.
- 1–2 estructuras pequeñas ya existentes (una caseta de guardia, un cobertizo) que sirven como referencia estética pero no como base obligatoria: el jugador puede construir donde quiera dentro del anillo.
- Punto de referencia visual alto (torre de vigilancia de madera o silo) que actúa como landmark visible desde buena parte del mapa, ayudando a la orientación sin necesitar minimapa.

### 2.2 Bosque Cercano (Anillo 1, norte y oeste)
- Bosque de densidad media: suficientes árboles para recolección de madera, pero con claros y sendas que evitan sensación de laberinto.
- Senderos de tierra marcados (huellas, ramas apartadas) que sugieren rutas sin ser caminos pavimentados.
- Pequeños asentamientos aislados: una cabaña de caza, un campamento de otros supervivientes abandonado (loot narrativo).

### 2.3 Pueblo Abandonado (Anillo 1, este)
- Un pueblo pequeño (6–10 edificios) con calle principal, tienda general, gasolinera, un par de casas residenciales.
- Zona de loot común/uncommon (comida, vendas, munición básica), ideal para primeras salidas.
- Vehículos volcados o detenidos en la calle principal (ver sección 2.6).
- Nivel de peligro bajo-medio: pocos zombies errantes, ideal para introducir a jugadores nuevos al combate.

### 2.4 Bosque Profundo (Anillo 2, norte)
- Densidad alta de árboles, menor visibilidad, más recursos de madera de calidad y zonas de caza (fauna decorativa/recolectable si el sistema de gameplay lo soporta).
- Terreno irregular (colinas suaves, rocas grandes) que dificulta la construcción — ver sección 6.
- Punto de interés: una torre de observación forestal caída, buen mirador y punto de loot rare.

### 2.5 Carretera y Puente (Anillo 2, cruzando el mapa este-oeste)
- Carretera principal semi-destruida que conecta el Pueblo Abandonado con la Zona Industrial.
- Fila de vehículos abandonados/accidentados — fuente de loot y de cobertura táctica.
- Un puente parcialmente colapsado sobre un río/arroyo que divide el mapa; cruzarlo es una ruta directa pero expuesta (sin cobertura), la alternativa es rodear por el bosque (más segura, más lenta) — esto crea una decisión real de ruta.

### 2.6 Zona Industrial / Aserradero (Anillo 2, sur)
- Un aserradero abandonado con maquinaria oxidada, silos de madera, plataformas elevadas.
- Buena zona de loot epic (herramientas avanzadas, piezas de construcción raras).
- Terreno semi-abierto con estructuras verticales: interesante para combate táctico y para colocar defensas en alturas.

### 2.7 Pantano (Anillo 3, sureste)
- Terreno anegado, niebla constante incluso de día, vegetación densa y retorcida.
- Movimiento más lento en zonas de agua poco profunda (si el sistema de movimiento lo soporta) — refuerza la sensación de riesgo.
- Loot legendary asociado a un pequeño asentamiento hundido/abandonado.

### 2.8 Cantera (Anillo 3, oeste)
- Gran hueco excavado en la roca, buena fuente de piedra/mineral.
- Paredes verticales que limitan las rutas de escape — zona de alto riesgo si se llena de zombies.
- Posible ubicación de evento/boss (ver sección 8).

### 2.9 Instalación Militar en Ruinas (Anillo 3, norte, la más alejada del centro)
- Un puesto de control o pequeña base militar colapsada, vallas de seguridad caídas, vehículos militares quemados.
- La zona de mayor riesgo y mayor recompensa del mapa: loot mythic, posible boss principal (sección 8), y el "secreto" mayor del mapa (sección 9).

---

## 3. Puntos de interés (resumen tabulado)

| Punto de interés | Anillo | Función principal | Riesgo |
|---|---|---|---|
| Torre de vigilancia (landmark central) | 0 | Orientación, mirador, posible punto defensivo | Muy bajo |
| Cabaña de caza | 1 | Loot uncommon, recurso de madera | Bajo |
| Campamento de supervivientes abandonado | 1 | Loot narrativo, pista de eventos futuros | Bajo |
| Calle principal del pueblo | 1 | Loot common/uncommon, introducción al combate | Bajo-medio |
| Gasolinera | 1 | Recursos de combustible (si aplica a gameplay futuro), loot uncommon | Medio |
| Torre de observación forestal caída | 2 | Loot rare, mirador táctico | Medio |
| Puente colapsado | 2 | Ruta rápida pero expuesta | Medio-alto |
| Fila de vehículos en carretera | 2 | Loot rare, cobertura táctica | Medio |
| Aserradero | 2 | Loot epic, combate vertical | Medio-alto |
| Pantano hundido | 3 | Loot legendary, ambientación de terror | Alto |
| Cantera | 3 | Recursos de piedra, posible boss | Alto |
| Instalación militar en ruinas | 3 | Loot mythic, boss principal, secreto mayor | Muy alto |

---

## 4. Rutas principales y secundarias

- **Ruta principal norte-sur:** Campamento Central → Bosque Cercano → Bosque Profundo → Instalación Militar. Es la ruta "de progresión natural", cada tramo un poco más peligroso que el anterior.
- **Ruta principal este-oeste:** Pueblo Abandonado → Puente/Carretera → Aserradero. Ruta más abierta y rápida, pero con menos cobertura (ideal para quienes priorizan velocidad sobre seguridad).
- **Ruta secundaria de bosque (rodeo del puente):** conecta Pueblo Abandonado con Zona Industrial bordeando el río por el bosque; más larga pero con más cobertura y menos exposición — alternativa táctica al puente.
- **Ruta secundaria sur (hacia la Cantera):** desvío desde el Aserradero, estrecha y entre rocas, pensada como "atajo arriesgado" hacia loot alto.
- **Sendero del pantano:** único acceso practicable al Anillo 3 sureste, deliberadamente angosto y con poca visibilidad para maximizar tensión.

Todas las rutas principales deben tener **al menos un punto de retirada visible** (zona abierta o elevación) donde el jugador pueda evaluar la situación antes de comprometerse, evitando pasillos de combate sin salida.

---

## 5. Ubicaciones de recursos

| Recurso | Ubicación principal | Ubicación secundaria |
|---|---|---|
| Madera | Bosque Cercano, Bosque Profundo | Cabaña de caza, Campamento de supervivientes |
| Piedra/mineral | Cantera | Aserradero (escombros), colinas del Bosque Profundo |
| Comida/agua | Pueblo Abandonado (tienda general, casas) | Cabaña de caza, Campamento Central (huerto/pozo decorativo) |
| Combustible | Gasolinera | Vehículos en carretera |
| Componentes mecánicos/herramientas | Aserradero, vehículos abandonados | Instalación militar |
| Medicinas | Casas del pueblo, campamento de supervivientes | Instalación militar (botiquín avanzado) |

**Regla de diseño:** los recursos básicos (madera, piedra, comida) siempre están disponibles cerca del Anillo 0/1 para que ninguna partida quede bloqueada por mala suerte de exploración; los recursos avanzados se concentran en los anillos exteriores para incentivar la progresión hacia zonas de riesgo.

---

## 6. Ubicaciones de loot

- **Común/Uncommon:** Pueblo Abandonado, Cabaña de caza — loot de fácil acceso para primeras salidas.
- **Rare:** Torre de observación caída, fila de vehículos en carretera, Aserradero (nivel bajo).
- **Epic:** Aserradero (zonas altas/interiores), Cantera.
- **Legendary:** Pantano hundido, zonas más profundas del Aserradero.
- **Mythic:** exclusivo de la Instalación Militar en ruinas y de eventos/bosses (sección 8).

El loot de mayor rareza siempre se ubica en zonas que requieren decisión activa de riesgo (rodeos, atajos peligrosos, zonas verticales) — nunca en el camino "de paso" obligatorio, para que encontrarlo se sienta como una elección del jugador.

---

## 7. Zonas buenas y malas para construir

### Buenas para construir
- **Campamento Central (Anillo 0):** terreno llano, visibilidad total, punto de partida natural — la opción "por defecto" y más segura.
- **Claros dentro del Bosque Cercano:** terreno razonablemente plano, cerca de recursos de madera, pero requiere más vigilancia que el centro.
- **Plataformas elevadas del Aserradero:** buena base "avanzada" para grupos que quieren una segunda base más cerca del Anillo 2, aprovechando la verticalidad para defensa.

### Malas para construir
- **Pantano:** terreno inestable, niebla constante, mala visibilidad — construir aquí debe ser posible pero claramente desaconsejable.
- **Cantera:** paredes verticales que limitan vías de escape, mala elección para una base permanente.
- **Puente y carretera abierta:** exposición total sin cobertura natural, terreno de paso, no de asentamiento.
- **Bosque Profundo, zonas de máxima densidad de árboles:** dificulta la construcción por espacio y visibilidad, mejor dejarlas como zona de recolección, no de base.

Esta distinción debe reflejarse visualmente (terreno llano y despejado = "invitación" a construir; terreno irregular/denso/inestable = "no aquí") sin necesidad de un sistema de reglas artificial — el propio diseño del terreno comunica la decisión.

---

## 8. Zonas de eventos y posibles bosses

- **Evento de oleada nocturna:** puede activarse en cualquier punto abierto cerca del Anillo 1 (ej. calle principal del pueblo), aprovechando la falta de cobertura para presión constante.
- **Evento de niebla del pantano:** evento temático ambientado en el Anillo 3 sureste, visibilidad reducida al mínimo, ideal para un "mini-boss" de pantano.
- **Boss de Cantera:** encuentro en el espacio cerrado de la cantera, aprovechando las paredes verticales como arena natural de combate.
- **Boss principal — Instalación Militar:** el encuentro de mayor escala del mapa, en el patio central de la instalación (espacio más abierto dentro de ese punto de interés), con las estructuras circundantes sirviendo de cobertura para el escuadrón.
- **Evento colaborativo de comunidad (ej. "Convoy de suministros"):** aparece de forma rotativa en la carretera principal (Anillo 2), recompensando a quien llegue e intervenga.

Todas las zonas de evento/boss están fuera del Anillo 0, de modo que la base del jugador nunca queda directamente amenazada por un boss — refuerza el bucle "prepararse → salir a enfrentar el evento → volver".

---

## 9. Suministros raros y secretos

- **Búnker oculto (secreto mayor):** entrada disimulada cerca de la Instalación Militar, escondida bajo escombros o una estructura caída — requiere exploración activa (no aparece en ninguna ruta principal). Contiene loot mythic garantizado.
- **Campamento de supervivientes con nota/pista:** en el Bosque Cercano, con un elemento narrativo simple (ej. un cartel pintado a mano) que insinúa la ubicación aproximada del búnker, incentivando la exploración sin ser un puzzle complejo.
- **Caja fuerte en la gasolinera:** pequeño secreto de nivel bajo-medio, premia a quien explore el pueblo a fondo en vez de solo pasar por la calle principal.
- **Vehículo militar hundido en el pantano:** secreto de nivel alto, visualmente coherente con la ambientación de pantano+abandono.

Los secretos deben poder encontrarse por observación del entorno (algo visualmente "fuera de lugar": una puerta entre escombros, una luz parpadeante lejana, un camino que no lleva a ningún punto de interés marcado) en vez de depender de mecánicas ocultas no comunicadas visualmente.

---

## 10. Spawns de zombies — reglas de diseño

**Principio central: nunca un spawn debe aparecer sobre el jugador ni dentro de su cono de visión inmediato.**

- **Puntos de spawn fijos en el borde de cada zona**, no dispersos aleatoriamente por todo el mapa — esto permite equilibrar la dificultad por zona y evitar que un spawn "aparezca detrás" de alguien de forma injusta.
- **Distancia mínima de spawn respecto a cualquier jugador:** los puntos de aparición deben estar fuera del rango de visión directa típico (aprox. equivalente a "fuera de un par de calles/claros de distancia"), nunca a espaldas inmediatas de un jugador quieto.
- **Densidad de spawns por anillo:**
  - Anillo 0: sin spawns propios (zona segura); solo pueden llegar zombies que migren desde el Anillo 1 durante eventos de oleada.
  - Anillo 1: densidad baja, puntos de spawn en los bordes exteriores del pueblo/bosque cercano, nunca en la calle principal misma.
  - Anillo 2: densidad media, puntos de spawn distribuidos en el bosque profundo y en los extremos de la carretera (no en el tramo central del puente, para no bloquear el cruce con apariciones injustas).
  - Anillo 3: densidad alta, puntos de spawn más numerosos pero igualmente respetando la regla de distancia mínima — el peligro debe sentirse por cantidad y ambientación, no por apariciones "tramposas".
- **Señal previa recomendada:** cuando sea posible, un sonido lejano o un cambio ambiental sutil (niebla que se espesa, aves que huyen) debería preceder la activación de un grupo de spawn, para que el peligro se perciba antes de materializarse — esto es una recomendación de diseño para cuando se implemente el sistema real de zombies, no una implementación en esta sesión.
- **Puntos de interés de alto valor (loot epic/legendary/mythic) tienen spawns más cercanos y numerosos** que el resto de su anillo, para que el riesgo esté directamente ligado a la recompensa.

---

## 11. Ciclo día/noche — cómo cambia el mapa

### Día
- Visibilidad alta, colores más saturados dentro de la paleta definida (verdes de bosque, marrones de tierra).
- Zombies en menor densidad activa en superficie (pueden seguir existiendo en interiores/sombra).
- Sonidos ambientales: viento entre árboles, algún crujido de estructuras, pájaros lejanos — refuerzan la sensación de "calma tensa", no de seguridad total.
- Niebla ligera solo en el Pantano (constante, es su seña de identidad) y ocasional en el Bosque Profundo al amanecer.

### Noche
- Iluminación ambiental reducida; fuentes de luz artificial (linternas de jugadores, alguna farola rota parpadeante en el pueblo, fuego de barriles si existieran) se vuelven el principal recurso de visibilidad.
- Aumento de densidad y agresividad de spawns en Anillos 1–3 (el Anillo 0 puede tener iluminación propia del campamento como incentivo a defenderlo).
- Niebla más extendida, especialmente en Bosque Profundo y Pantano.
- Sonidos ambientales cambian a: gruñidos lejanos ocasionales, silencio más marcado (ausencia de pájaros), crujidos de madera más frecuentes — usar el silencio como herramienta de tensión, no solo el ruido.
- Posibilidad de tormentas nocturnas (ver abajo) como variante de mayor intensidad.

### Lluvia y tormentas (evento climático opcional)
- **Lluvia ligera:** reduce visibilidad moderadamente, añade sonido ambiental de lluvia sobre hojas/techos, superficies con un brillo sutil (sin efectos costosos de mojado real).
- **Tormenta:** lluvia intensa + relámpagos ocasionales (destello breve de luz, nunca estroboscópico prolongado por accesibilidad), viento fuerte audible, visibilidad reducida especialmente en zonas abiertas (carretera, campamento central).
- Las tormentas son ideales para ambientar eventos especiales o el evento de "oleada nocturna" (sección 8), incrementando la tensión sin necesitar más zombies, solo peor visibilidad y sonido.

### Señales de abandono (elementos ambientales recurrentes, día y noche)
- Carteles caseros de advertencia escritos a mano en el pueblo y accesos a zonas peligrosas.
- Vehículos abandonados con puertas abiertas, maletas/objetos esparcidos cerca.
- Restos de campamentos improvisados de otros supervivientes (fogatas apagadas, tiendas caídas).
- Vallas y barricadas viejas, algunas efectivas, otras claramente vencidas — comunican visualmente que "otros lo intentaron antes".

### Iluminación general
- Paleta de luz cálida y tenue durante el día (sin sobreexponer, manteniendo el tono "apagado" del apocalipsis).
- Paleta de luz fría/azulada durante la noche, con acentos cálidos puntuales (linternas, alguna luz eléctrica sobreviviente) para que el jugador identifique rápido las fuentes de seguridad visual.
- Evitar iluminación global muy oscura que dificulte jugar en dispositivos móviles con pantallas de bajo brillo — la oscuridad debe sentirse sin volverse imposible de leer.

---

## 12. Ideas para 3 futuros mapas (misma identidad visual)

1. **"Costa Varada"** — versión costera del mismo universo: pueblo pesquero abandonado, barcos varados, un faro como landmark central (equivalente a la torre de vigilancia), niebla marina en vez de niebla de pantano, tormentas más frecuentes por ser zona costera. Mantiene la estructura de anillos (playa/pueblo seguro → acantilados y muelles → mar abierto/naufragios como zona de mayor riesgo).
2. **"Valle de la Represa"** — zona industrial/rural con una represa hidroeléctrica en ruinas como landmark central, campos de cultivo abandonados como Anillo 1, y un pueblo minero como zona de riesgo alto en el Anillo 3, con la propia represa como posible escenario de boss (combate en estructura vertical/industrial, similar en espíritu al Aserradero pero a mayor escala).
3. **"Nevado del Norte"** — variante de temporada fría: mismo bosque pero cubierto de nieve, visibilidad reducida por ventisca en vez de niebla, cabañas de montaña como puntos de interés principales, y un refugio militar de alta montaña como equivalente a la Instalación Militar. Ideal para reutilizar activos del mapa base con reskin de temporada (coherente con la skin "Invierno" ya definida en `R6_VISUAL_DESIGN.md`).

Los tres mantienen la misma lógica de anillos, la misma regla de spawns y la misma paleta general adaptada al bioma, para que cualquier mapa futuro se sienta parte de la misma familia visual sin duplicar trabajo de diseño desde cero.

---

## 13. Guía de Creator Store para modelos del mundo

**Regla de oro (igual que en `R6_VISUAL_DESIGN.md`):** ningún Free Model se considera seguro por defecto. Todo modelo externo se revisa manualmente —scripts innecesarios, sospechosos o backdoors se eliminan— antes de considerar incorporarlo, y nunca se integra automáticamente al proyecto principal.

| Categoría | Términos a buscar | Estilo a elegir | Qué revisar antes de usar |
|---|---|---|---|
| Árboles | "low poly forest tree pack", "stylized pine roblox" | Baja densidad de polígonos, colores planos, packs variados de tamaño/inclinación para evitar repetición visual | Conteo de triángulos por árbol, que no traiga scripts, variación suficiente para plantar en masa sin verse clonado |
| Casas | "abandoned house low poly roblox", "small house stylized" | Estructuras simples, techos a dos aguas, madera/chapa envejecida, coherente con paleta de tierra/madera | Colisiones correctas, ausencia de scripts embebidos, que el interior (si lo tiene) no sea excesivo si solo se usará el exterior |
| Cabañas | "cabin low poly", "forest cabin roblox stylized" | Madera envejecida, tamaño pequeño-mediano, techo simple | Igual que casas; verificar que el nivel de detalle combine con el resto de estructuras del pueblo |
| Vehículos | "abandoned car pack roblox", "rusty truck low poly", "wrecked car stylized" | Siluetas simples, óxido como textura, sin sistemas de conducción si no se van a usar | Scripts de manejo no deseados, número de partes sueltas, que las colisiones no generen problemas al caminar alrededor |
| Rocas | "low poly rock pack roblox", "stylized boulder" | Formas simples, buena variedad de tamaños para cantera y bosque | Que no traigan materiales/texturas excesivamente pesadas, variedad suficiente para evitar repetición |
| Muebles | "post apocalyptic furniture pack", "low poly interior props" | Desgaste sutil, formas simples, agrupados por tema (casa/cabaña) | Usar solo lo necesario del pack, revisar que no incluyan scripts de interacción no deseados |
| Ruinas | "ruined building roblox", "collapsed structure low poly" | Coherente con nivel de detalle del resto del mapa, ni muy limpio ni excesivamente caótico | Verificar colisiones en zonas de escombros para que no bloqueen rutas de forma involuntaria |
| Señales | "road sign pack roblox", "warning sign low poly", "handmade sign stylized" | Texto legible a distancia si aplica, estilo casero para carteles de advertencia | Que el texto/idioma sea editable o reemplazable, tamaño de textura razonable |
| Decoración (fogatas, escombros, vegetación muerta) | "overgrown ruins props", "campfire pack roblox", "debris low poly" | Sutileza sobre exceso; reforzar señales de abandono sin saturar la escena | Cantidad de partículas/luces incluidas (fogatas con PointLight deben evaluarse contra el presupuesto de rendimiento), que no traigan sonidos con derechos poco claros |

**Checklist rápido (igual criterio que en el documento visual):** abrir en entorno aislado → revisar jerarquía en busca de Scripts no esperados → eliminar todo lo no estrictamente visual → revisar triángulos/texturas frente al presupuesto de rendimiento → documentar origen antes de aprobar, sin integrar nada automáticamente al proyecto principal.

---

## 14. Resumen para quien implemente el mapa más adelante

- El mapa se piensa en **3 anillos de riesgo creciente** alrededor de una base central segura, no como una cuadrícula uniforme — esto es lo primero que debería reflejarse en el layout real.
- Cada punto de interés tiene ya asignado: anillo, función y nivel de riesgo (tabla sección 3), lo que permite planificar el terreno real sin ambigüedad.
- Las reglas de spawn de zombies (sección 10) son el requisito más importante a respetar cuando se implemente el sistema real: spawns fijos, en bordes de zona, nunca sobre el jugador.
- Las zonas buenas/malas para construir (sección 7) ya están comunicadas por el propio diseño del terreno, no requieren un sistema de reglas artificial adicional.
- Este documento no crea ni modifica ningún sistema de gameplay, terreno real, ni archivo del proyecto `ZombieSurvival` — es la referencia de diseño para cuando esa fase comience.

---

*Fin del documento. Archivo nuevo e independiente — no se modificó ningún archivo del proyecto `ZombieSurvival` original.*
