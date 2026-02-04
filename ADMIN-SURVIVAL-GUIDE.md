# 🛡️ ADMIN SURVIVAL GUIDE — Manejo de Participantes Demandantes

## 🎯 Cómo Decir "NO" Sin Sonar Culero

### **Frases Pre-fabricadas para Equipos Insistentes:**

#### **"¿Nos puedes ayudar?"**
✅ **Respuesta:** *"Claro, pero este CTF está diseñado para que aprendan haciendo. ¿Ya intentaron usar los filtros básicos en FortiAnalyzer?"*

❌ **NO digas:** *"Está muy fácil, búsquenle"*

#### **"No sabemos ni por dónde empezar"**
✅ **Respuesta:** *"Perfecto, es normal. Empiecen siempre por el Dashboard principal. ¿Ya pueden ver logs ahí?"*

❌ **NO digas:** *"Lean la documentación"*

#### **"¿Esta es la respuesta correcta?" (te enseñan su pantalla)**
✅ **Respuesta:** *"Interesante enfoque. ¿Qué criterio usaron para llegar a ese resultado? Valídenlo ustedes."*

❌ **NO digas:** *"Sí/No"* (nunca confirmes respuestas)

---

## 📋 PROTOCOLO DE AYUDA ESCALONADO

### **Nivel 1: Auto-Suficiencia (Primer Contacto)**
**Objetivo:** Que resuelvan solos con dirección mínima

**Frases mágicas:**
- *"¿Ya exploraron todas las pestañas de FortiAnalyzer?"*
- *"¿Qué pasa si cambian el rango de tiempo?"*
- *"¿Ya probaron hacer clic derecho en esos logs?"*
- *"Muy bien, van por buen camino. ¿Qué más ven en esa pantalla?"*

### **Nivel 2: Hint Direccional (Siguen atorados después de 10 min)**
**Objetivo:** Darles la dirección correcta sin resolver

**Ejemplos por reto:**
```
Reto "Primera Vista": "El número que buscan aparece en la parte superior cuando filtran correctamente"

Reto "Correlador": "Los atacantes dejan rastros en múltiples eventos. ¿Ven algún patrón en las IPs?"

Reto "Timeline": "Los ataques tienen secuencia temporal. ¿Cuál fue el último paso que hizo el atacante?"
```

### **Nivel 3: Hint Específico (>20 min atorados)**
**Objetivo:** Evitar frustración total, pero que sigan trabajando

**Script:**
*"OK, les voy a dar una pista más específica porque veo que están batallando. [HINT ESPECÍFICO]. Ahora intenten con eso y me dicen qué encuentran."*

### **Nivel 4: Walkthrough Parcial (Solo casos extremos)**
**Objetivo:** Último recurso para evitar que abandonen

**Script:**
*"Miren, les voy a mostrar los primeros 2 pasos para que no se frustren, pero el resto tienen que hacerlo ustedes..."*

---

## 😤 MANEJO DE EQUIPOS PROBLEMÁTICOS

### **Tipo 1: "Los Demandantes" - Quieren que hagas todo**
**Síntomas:** *"¿Nos puedes mostrar cómo?"* cada 2 minutos

**Estrategia:**
1. **Set expectations:** *"Este CTF es hands-on learning. Mi trabajo es guiarlos, no resolverlo por ustedes."*
2. **Redirect:** *"¿Qué han intentado ya?"* (siempre pregunta esto primero)
3. **Time limits:** *"Les doy 5 minutos para intentar X, después vengo a ver cómo van"*

**Frase de cierre:** *"Confío en que pueden resolverlo. El aprendizaje viene de la lucha, no de que yo se los dé resuelto."*

### **Tipo 2: "Los Frustrados" - Se enojan cuando no funciona**
**Síntomas:** *"Esto está roto"* / *"No sirve"* / *"Es imposible"*

**Estrategia:**
1. **Validate feelings:** *"Entiendo la frustración, es parte del proceso"*
2. **Redirect energy:** *"Canalicemos esa energía. ¿Ya probaron esto...?"*
3. **Success stories:** *"El equipo 3 ya resolvió este reto, sí se puede"*

**Si se ponen muy intensos:** *"Tomen un break de 10 minutos, refrésquense, y regresamos con mente clara"*

### **Tipo 3: "Los Copiadores" - Quieren ver la pantalla de otros equipos**
**Síntomas:** Voltean a ver a otros, preguntan *"¿Cómo van los demás?"*

**Estrategia:**
1. **Block info:** *"Cada equipo va a su ritmo, enfóquense en ustedes"*
2. **Redirect competition:** *"Su competencia es el tiempo, no los otros equipos"*
3. **Physical intervention:** Párate entre equipos si es necesario

### **Tipo 4: "Los Abandonadores" - Se rinden fácil**
**Síntomas:** *"Ya no podemos"* / *"Esto es muy difícil"*

**Estrategia:**
1. **Break it down:** *"No piensen en resolver todo. Solo enfóquense en el siguiente paso pequeño"*
2. **Celebrate progress:** *"Ya lograron X y Y, están más cerca de lo que creen"*
3. **Peer pressure:** *"Los otros equipos también están batallando, es normal"*

---

## 🎭 FRASES PARA MANTENER LA AUTORIDAD

### **Cuando insisten mucho:**
*"Entiendo que quieren avanzar rápido, pero parte del valor de este ejercicio es desarrollar la capacidad de análisis. Si les doy la respuesta, pierden ese beneficio."*

### **Cuando dicen "está muy difícil":**
*"Está calibrado para su nivel. Miles de analistas SOC hacen esto diariamente. Ustedes también pueden."*

### **Cuando piden la respuesta directa:**
*"Si quisiera que memorizaran respuestas, les habría dado un examen de opción múltiple. Esto es para que piensen como analysts reales."*

### **Cuando otros equipos se quejan de ayuda:**
*"Todos reciben el mismo nivel de ayuda. Si sienten que necesitan más, vengan y pregunten específicamente."*

---

## 📊 SISTEMA DE MONITOREO PARA EVITAR DRAMA

### **Dashboard Personal (tu cheat sheet):**
```
Team 1: Stuck en Reto 3 (15 min) - Needs Hint Level 2
Team 2: Progressing well - Leave alone  
Team 3: Frustrated (Reto 5) - Check in 5 min
Team 4: Demandantes activos - Set boundaries
Team 5: Silent but struggling - Proactive check
```

### **Alertas Automáticas:**
- 🟡 **15+ min sin progress:** Proactive check-in
- 🔴 **Negative comments detected:** Intervention needed  
- 🟢 **Flag submitted:** Positive reinforcement opportunity

---

## 🔧 HERRAMIENTAS DE EMERGENCIA

### **"Reset Mental" para Equipos Frustrados:**
1. **Acknowledge:** *"Veo que están frustrados"*
2. **Normalize:** *"Esto pasa en todos los CTFs"*  
3. **Refocus:** *"Vamos a empezar este reto desde cero, paso por paso"*
4. **Small win:** Ensure first step works to build confidence

### **"Confidence Boost" para Equipos Desanimados:**
*"Están pensando correctamente. El hecho de que estén haciendo estas preguntas me dice que van por el camino correcto. Solo necesitan persistir un poco más."*

### **"Reality Check" para Equipos Demandantes:**
*"Entiendo que el tiempo apremia, pero en un SOC real nadie va a estar ahí para darles las respuestas. Este ejercicio los está preparando para eso."*

---

## 💬 SCRIPTS DE CONVERSACIÓN PROBADOS

### **Inicio de Interacción (siempre):**
1. **"¿Qué han intentado hasta ahora?"** (nunca ayudes sin saber esto)
2. **"¿Qué específicamente no está funcionando?"**
3. **"¿Ya revisaron [área básica]?"**

### **Dar Hint sin Resolver:**
1. **"Les voy a dar una dirección, pero ustedes tienen que llegar"**
2. **"¿Qué creen que significa esto que están viendo?"**
3. **"Si fueran analistas SOC reales, ¿qué harían aquí?"**

### **Cerrar Interacción:**
1. **"Perfecto, intenten eso y me dicen cómo les va"**
2. **"¿Tienen claro el siguiente paso?"**
3. **"Los veo en 10 minutos para ver su progreso"**

---

## ⚠️ SEÑALES DE ALERTA - CUANDO INTERVENIR MÁS

### **Intervención Inmediata Necesaria:**
- Team completamente callado por >30 min
- Comentarios negativos sobre Fortinet/CTF
- Discusiones internas del equipo (conflict)
- Alguien en el celular ignorando el ejercicio

### **Frases de Intervención:**
*"¿Cómo van? Noto que han estado callados. ¿En qué los puedo orientar?"*

*"Veo que hay diferentes opiniones en el equipo. ¿Quieren que les ayude a estructurar su enfoque?"*

---

## 🎯 TU OBJETIVO COMO ADMIN

**✅ Lo que SÍ quieres:**
- Equipos trabajando independientemente
- Preguntas inteligentes y específicas
- Progress steady (no necesariamente rápido)
- Aprendizaje real aconteciendo

**❌ Lo que NO quieres:**
- Dependencia de ti para cada paso
- Teams frustrados al punto de rendirse
- Complaints sobre dificultad
- Copying between teams

**🎭 Tu role:** **Coach, no profesor.** **Guide, no solver.**

---

## 📝 CHEAT SHEET DE BOLSILLO

**Pregunta #1:** *"¿Qué han intentado?"*  
**Hint Rule:** 3 levels max, then partial walkthrough  
**Frustration:** Normalize + refocus  
**Demands:** Set boundaries firmly but kindly  
**Success:** Celebrate and ask "¿cómo llegaron ahí?"

**Recuerda:** Es mejor que batalles y aprendan, que no que les regales respuestas y no aprendan nada. 💪