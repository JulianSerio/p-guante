import processing.serial.*;
import peasy.*;

PeasyCam cam;
float rotacion = 0;
float velocidad = 0.5;
boolean autoRotate = true;

// Sistema de dedos
Dedo[] dedos = new Dedo[5];
String[] nombresDedos = {"Pulgar", "Índice", "Medio", "Anular", "Meñique"};
int dedoSeleccionado = 0;
int falangeSeleccionada = 0;
String[] nombresFalanges = {"Proximal", "Medial", "Distal"};

color colorPiel = color(220, 195, 165);
color colorArticulacion = color(200, 170, 140);
color colorUña = color(240, 230, 220);

// Comunicación serial con Arduino
Serial myPort;
float[] flexValues = {0, 0, 0, 0, 0}; // Valores de flexión de los dedos
boolean recibiendoDatos = false;

// Configuración para cada dedo
boolean[] dedoConectado = {true, true, true, false, false}; // Cambia según qué dedos tienes conectados
boolean invertirFlexion = true; // Cambia a false si la flexión está invertida
float[] minValores = {300, 300, 300, 300, 300}; // Valores mínimos para cada sensor
float[] maxValores = {700, 700, 700, 700, 700}; // Valores máximos para cada sensor

// Sistema de colisión con pelota
Pelota pelota;
boolean[] colisiones = new boolean[5]; // Para cada dedo
int[] estadosVibracion = {0, 0, 0, 0, 0}; // Estados para enviar a Arduino

void setup() {
  size(1200, 800, P3D);
  cam = new PeasyCam(this, 400);

  // Dedos: x, y, z, largoProx, largoMed, largoDist, grosorBase, anguloBase
  dedos[0] = new Dedo(-35, -15, 30, 22, 16, 10, 12, -60);  // Pulgar
  dedos[1] = new Dedo(-25, -15, 35, 38, 24, 18, 9, 0);     // Índice
  dedos[2] = new Dedo(0, -15, 40, 43, 28, 20, 10, 0);      // Medio
  dedos[3] = new Dedo(25, -15, 37, 40, 26, 19, 9, 0);      // Anular
  dedos[4] = new Dedo(45, -10, 28, 30, 20, 15, 7, 5);      // Meñique
  pelota = new Pelota(new PVector(0, -40, -25), 40, color(0, 150, 255), color(255, 100, 100));


  // Configurar comunicación serial
  println("Puertos seriales disponibles:");
  printArray(Serial.list());
  
  // Intenta conectarse al puerto serial (ajusta el índice según sea necesario)
  try {
    String portName = Serial.list()[0]; // Cambia este índice si es necesario
    myPort = new Serial(this, portName, 9600);
    myPort.bufferUntil('\n');
    println("Conectado al puerto: " + portName);
    recibiendoDatos = true;
  } catch (Exception e) {
    println("Error al conectar con Arduino: " + e.getMessage());
    println("Modo simulación activado. Usa las teclas para controlar los dedos.");
    recibiendoDatos = false;
    
    // Valores por defecto para simulación
    for (int i = 0; i < flexValues.length; i++) {
      flexValues[i] = 500;
    }
  }
}

void draw() {
  background(50, 60, 80);
  ambientLight(60, 60, 80);
  directionalLight(255, 255, 255, -1, 0.5, -1);
  pointLight(200, 200, 255, 100, -100, 200);

  if (autoRotate) {
    rotateY(radians(rotacion));
    rotacion += velocidad;
  }

  dibujarPalma();
  dibujarMuñeca();

  // Actualizar ángulos de los dedos según los valores de flexión
  actualizarDedos();
  
  // Dibujar y verificar colisión con la pelota
  dibujarPelota();
  verificarColisiones();
  
  // Dibujar dedos
  for (int i = 0; i < dedos.length; i++) {
    dedos[i].display(i == dedoSeleccionado);
  }

  // Enviar datos de vibración a Arduino
  if (recibiendoDatos) {
    enviarDatosVibracion();
  }

  dibujarUI();
}

void actualizarDedos() {
  // Mapear valores de flexión a ángulos de los dedos
  for (int i = 0; i < dedos.length; i++) {
    if (dedoConectado[i]) {
      // Si el dedo está conectado, usar valores reales
      float angulo;
      if (invertirFlexion) {
        // Invertir el mapeo para corregir flexión/extensión
        angulo = map(flexValues[i], minValores[i], maxValores[i], 90, 0);
      } else {
        // Mapeo normal
        angulo = map(flexValues[i], minValores[i], maxValores[i], 0, 90);
      }
      angulo = constrain(angulo, 0, 90);
      
      // Distribuir la flexión entre las falanges
      dedos[i].angProx = angulo * 0.5;
      dedos[i].angMed = angulo * 0.7;
      dedos[i].angDist = angulo * 0.9;
    } else {
      // Si el dedo no está conectado, mantenerlo extendido
      dedos[i].angProx = 0;
      dedos[i].angMed = 0;
      dedos[i].angDist = 0;
    }
  }
}

void dibujarPelota() {
  boolean hayColision = false;
  for (boolean col : colisiones) {
    if (col) {
      hayColision = true;
      break;
    }
  }
  pelota.display(hayColision);
}

void verificarColisiones() {
  for (int i = 0; i < dedos.length; i++) {
    PVector punta = calcularPuntaDedo(dedos[i]);
    colisiones[i] = pelota.colisionaCon(punta);
    estadosVibracion[i] = colisiones[i] ? 1 : 0;
  }
}


PVector calcularPuntaDedo(Dedo dedo) {
  // Calcular la posición de la punta del dedo en el espacio mundial
  // Esta función es crítica para la detección de colisiones
  
  // Empezamos en la base del dedo (posición relativa a la palma)
  PVector posicion = new PVector(dedo.x, dedo.y, dedo.z);
  
  // Aplicar la rotación base del dedo (especialmente importante para el pulgar)
  float radBase = radians(dedo.anguloBase);
  float xRot = posicion.x * cos(radBase) - posicion.y * sin(radBase);
  float yRot = posicion.x * sin(radBase) + posicion.y * cos(radBase);
  posicion.set(xRot, yRot, posicion.z);
  
  // Ahora calculamos el efecto de las rotaciones de cada falange
  // Usamos ángulos acumulativos
  float anguloAcumuladoX = radians(dedo.angProx);
  
  // Primera falange (proximal)
  float yOffset1 = -dedo.largoProx * cos(anguloAcumuladoX);
  float zOffset1 = dedo.largoProx * sin(anguloAcumuladoX);
  posicion.add(new PVector(0, yOffset1, zOffset1));
  
  // Segunda falange (medial)
  anguloAcumuladoX += radians(dedo.angMed);
  float yOffset2 = -dedo.largoMed * cos(anguloAcumuladoX);
  float zOffset2 = dedo.largoMed * sin(anguloAcumuladoX);
  posicion.add(new PVector(0, yOffset2, zOffset2));
  
  // Tercera falange (distal)
  anguloAcumuladoX += radians(dedo.angDist);
  float yOffset3 = -dedo.largoDist * cos(anguloAcumuladoX);
  float zOffset3 = dedo.largoDist * sin(anguloAcumuladoX);
  posicion.add(new PVector(0, yOffset3, zOffset3));
  
  return posicion;
}

void enviarDatosVibracion() {
  // Preparar datos para enviar a Arduino
  String datos = "";
  for (int i = 0; i < estadosVibracion.length; i++) {
    datos += str(estadosVibracion[i]);
    if (i < estadosVibracion.length - 1) {
      datos += ",";
    }
  }
  datos += "\n";
  myPort.write(datos);
  //println("Enviando a Arduino: " + datos); // Descomenta para depuración
}

void dibujarPalma() {
  pushMatrix();
  translate(0, 0, 35);
  fill(colorPiel);
  noStroke();
  
  // Escalar esfera para que tenga forma de palma redondeada
  pushMatrix();
  scale(1.1, 0.8, 0.5); // ancho, alto, profundidad
  sphere(45);
  popMatrix();
  
  popMatrix();
}

void dibujarMuñeca() {
  pushMatrix();
  translate(0, 60, 35);
  fill(colorPiel);
  noStroke();
  rotateX(0);
  cylinderRecto(20, 40);
  popMatrix();
}

// -----------------------------------------
// CLASE PELOTA
// -----------------------------------------
class Pelota {
  PVector posicion;
  float radio;
  color colorBase;
  color colorColision;

  Pelota(PVector posicion, float radio, color colorBase, color colorColision) {
    this.posicion = posicion.copy();
    this.radio = radio;
    this.colorBase = colorBase;
    this.colorColision = colorColision;
  }

  void display(boolean hayColision) {
    pushMatrix();
    translate(posicion.x, posicion.y, posicion.z);
    fill(hayColision ? colorColision : colorBase);
    noStroke();
    sphere(radio);
    popMatrix();
  }

  boolean colisionaCon(PVector punto) {
    float dx = punto.x - posicion.x;
    float dy = punto.y - posicion.y;
    float dz = punto.z - posicion.z;
  
    float distancia = sqrt(dx * dx + dy * dy + dz * dz);
    return distancia <= radio;
  }

}

// -----------------------------------------
// CLASE DEDO
// -----------------------------------------
class Dedo {
  float x, y, z;
  float angProx = 0, angMed = 0, angDist = 0;
  float largoProx, largoMed, largoDist;
  float grosorBase;
  float anguloBase;

  float[] limitesMin = {-20, -10, -10};
  float[] limitesMax = {90, 100, 80};

  Dedo(float x, float y, float z, float lp, float lm, float ld, float grosor, float angBase) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.largoProx = lp;
    this.largoMed = lm;
    this.largoDist = ld;
    this.grosorBase = grosor;
    this.anguloBase = angBase;
  }

  void display(boolean seleccionado) {
    pushMatrix();
    translate(x, y, z);

    // Pulgar se rota lateralmente
    rotateZ(radians(anguloBase));

    rotateX(radians(angProx));
    dibujarFalangeConPunta(largoProx, grosorBase);
    
    translate(0, -largoProx, 0);
    rotateX(radians(angMed));
    dibujarFalangeConPunta(largoMed, grosorBase * 0.8);
    
    translate(0, -largoMed, 0);
    rotateX(radians(angDist));
    dibujarFalangeConPunta(largoDist, grosorBase * 0.6);

    popMatrix();
  }

  void moverFalange(int falange, float incremento) {
    float nuevoAngulo;
    switch(falange) {
    case 0:
      angProx = constrain(angProx + incremento, limitesMin[0], limitesMax[0]);
      break;
    case 1:
      angMed  = constrain(angMed  + incremento, limitesMin[1], limitesMax[1]);
      break;
    case 2:
      angDist = constrain(angDist + incremento, limitesMin[2], limitesMax[2]);
      break;
    }
  }

  void cerrar(float factor) {
    angProx = lerp(angProx, limitesMax[0] * factor, 0.1);
    angMed  = lerp(angMed, limitesMax[1] * factor, 0.1);
    angDist = lerp(angDist, limitesMax[2] * factor, 0.1);
  }

  void abrir() {
    angProx = lerp(angProx, 0, 0.1);
    angMed  = lerp(angMed, 0, 0.1);
    angDist = lerp(angDist, 0, 0.1);
  }
}

// -----------------------------------------
// FUNCIONES AUXILIARES
// -----------------------------------------
void dibujarFalangeConPunta(float largo, float grosor) {
  noStroke();
  
  // --- Cuerpo de la falange (cilindro recto) ---
  cylinderRecto(grosor, largo);
  
  // --- Punta del dedo (esfera pequeña) ---
  pushMatrix();
  translate(0, -largo, 0);   
  fill(colorUña);
  sphere(grosor * 0.8);
  popMatrix();               
}

void cylinderRecto(float r, float h) {
  int sides = 16;
  float angle = TWO_PI / sides;

  // Cuerpo
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float x = cos(i * angle) * r;
    float z = sin(i * angle) * r;
    vertex(x, 0, z);
    vertex(x, -h, z);
  }
  endShape();

  // Tapa inferior
  beginShape();
  for (int i = sides - 1; i >= 0; i--) {
    float x = cos(i * angle) * r;
    float z = sin(i * angle) * r;
    vertex(x, 0, z);
  }
  endShape(CLOSE);
}

// -----------------------------------------
// INTERFAZ DE USUARIO
// -----------------------------------------
void dibujarUI() {
  cam.beginHUD();
  fill(0, 0, 0, 150);
  rect(10, 10, 400, 220);
  fill(255);
  textSize(14);
  text("GUANTE HÁPTICO - CONTROL DE DEDOS", 20, 30);
  text("Dedo: " + nombresDedos[dedoSeleccionado], 20, 50);
  text("Falange: " + nombresFalanges[falangeSeleccionada], 20, 70);
  text("Valores flexión: " + java.util.Arrays.toString(flexValues), 20, 90);
  text("Estado: " + (recibiendoDatos ? "Conectado a Arduino" : "Modo simulación"), 20, 110);
  text("Dedos conectados: " + getDedosConectadosTexto(), 20, 130);
  text("Invertir flexión: " + (invertirFlexion ? "SÍ" : "NO"), 20, 150);
  text("Colisiones: " + getColisionesTexto(), 20, 170);
  textSize(12);
  text("CONTROLES MANUALES:", 20, 195);
  text("1-5: Seleccionar dedo | Q-W-E: Seleccionar falange", 20, 210);
  text("↑/↓: Flexionar | SPACE: Rotar automática | I: Invertir flexión", 20, 225);
  cam.endHUD();
}

String getDedosConectadosTexto() {
  String texto = "";
  for (int i = 0; i < dedoConectado.length; i++) {
    texto += (dedoConectado[i] ? "✓" : "✗") + " ";
  }
  return texto;
}

String getColisionesTexto() {
  String texto = "";
  for (int i = 0; i < colisiones.length; i++) {
    texto += (colisiones[i] ? "✔" : "✖") + " ";
  }
  return texto;
}

// -----------------------------------------
// TECLADO
// -----------------------------------------
void keyPressed() {
  if (key >= '1' && key <= '5') dedoSeleccionado = key - '1';
  if (key == 'q' || key == 'Q') falangeSeleccionada = 0;
  if (key == 'w' || key == 'W') falangeSeleccionada = 1;
  if (key == 'e' || key == 'E') falangeSeleccionada = 2;

  if (keyCode == UP) dedos[dedoSeleccionado].moverFalange(falangeSeleccionada, 5);
  if (keyCode == DOWN) dedos[dedoSeleccionado].moverFalange(falangeSeleccionada, -5);

  if (key == ' ') autoRotate = !autoRotate;
  if (keyCode == LEFT) velocidad -= 0.2;
  if (keyCode == RIGHT) velocidad += 0.2;

  if (key == 'c' || key == 'C') for (Dedo dedo : dedos) dedo.cerrar(1.0);
  if (key == 'o' || key == 'O') for (Dedo dedo : dedos) dedo.abrir();
  if (key == 'r' || key == 'R') for (Dedo dedo : dedos) {
    dedo.angProx=0;
    dedo.angMed=0;
    dedo.angDist=0;
  }
  
  // Tecla 'I' para invertir la flexión
  if (key == 'i' || key == 'I') {
    invertirFlexion = !invertirFlexion;
    println("Invertir flexión: " + invertirFlexion);
  }
  
  // Teclas para configurar dedos conectados (F1-F5)
  if (keyCode == 112) dedoConectado[0] = !dedoConectado[0]; // F1 - Pulgar
  if (keyCode == 113) dedoConectado[1] = !dedoConectado[1]; // F2 - Índice
  if (keyCode == 114) dedoConectado[2] = !dedoConectado[2]; // F3 - Medio
  if (keyCode == 115) dedoConectado[3] = !dedoConectado[3]; // F4 - Anular
  if (keyCode == 116) dedoConectado[4] = !dedoConectado[4]; // F5 - Meñique
  
  // Teclas para mover la pelota (teclas de dirección + Shift)
  if (keyCode == UP && (keyEvent.isShiftDown())) {
    pelota.posicion.y -= 10;
  }
  if (keyCode == DOWN && (keyEvent.isShiftDown())) {
    pelota.posicion.y += 10;
  }
  if (keyCode == LEFT && (keyEvent.isShiftDown())) {
    pelota.posicion.x -= 10;
  }
  if (keyCode == RIGHT && (keyEvent.isShiftDown())) {
    pelota.posicion.x += 10;
  }
  if ((key == 'z' || key == 'Z') && (keyEvent.isShiftDown())) {
    pelota.posicion.z -= 10;
  }
  if ((key == 'x' || key == 'X') && (keyEvent.isShiftDown())) {
    pelota.posicion.z += 10;
  }
}

// -----------------------------------------
// COMUNICACIÓN SERIAL CON ARDUINO
// -----------------------------------------
void serialEvent(Serial p) {
  try {
    String line = p.readStringUntil('\n');
    if (line != null) {
      line = line.trim();
      String[] vals = line.split(",");
      if (vals.length == 5) {
        for (int i = 0; i < 5; i++) {
          flexValues[i] = float(vals[i]);
        }
        recibiendoDatos = true;
      }
    }
  } catch (Exception e) {
    println("Error reading serial data: " + e.getMessage());
  }
}

// -----------------------------------------
// RATÓN para mover la pelota
// -----------------------------------------
void mouseDragged() {
  if (mouseButton == RIGHT) {
    // Mover la pelota con el botón derecho del ratón
    pelota.posicion.x += (mouseX - pmouseX) * 0.5;
    pelota.posicion.y += (mouseY - pmouseY) * 0.5;
  }
}
