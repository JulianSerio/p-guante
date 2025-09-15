/*
  Guante de Realidad Virtual con retroalimentación háptica
  - 5 sensores flex (uno por dedo)
  - 5 motores vibradores (uno por dedo)
  - Comunicación serial con Processing
*/

const int flexPins[5] = {A0, A1, A2, A3, A4};   // Pines analógicos sensores flex
const int motorPins[5] = {3, 5, 6, 9, 10};      // Pines PWM motores vibradores

int flexValues[5];
int motorStates[5] = {0,0,0,0,0}; // estados que vienen desde Processing (1 = vibrar, 0 = apagado)

void setup() {
  Serial.begin(9600);
  
  // Configurar pines motores como salida
  for (int i = 0; i < 5; i++) {
    pinMode(motorPins[i], OUTPUT);
    digitalWrite(motorPins[i], LOW);
  }
}

void loop() {
  // Leer flexión de cada dedo
  for (int i = 0; i < 5; i++) {
    flexValues[i] = analogRead(flexPins[i]);
  }

  // Enviar valores de flexión a Processing en formato CSV
  for (int i = 0; i < 5; i++) {
    Serial.print(flexValues[i]);
    if (i < 4) Serial.print(",");
  }
  Serial.println();

  // Si hay datos desde Processing → actualizar motores
  if (Serial.available() > 0) {
    String data = Serial.readStringUntil('\n');
    data.trim(); // Eliminar espacios y retornos de carro
    if (data.length() >= 9) { // Verificar que tenga longitud suficiente (ej: "1,0,0,1,0")
      parseMotorData(data);
    }
  }

  // Aplicar vibración según lo recibido
  for (int i = 0; i < 5; i++) {
    analogWrite(motorPins[i], motorStates[i] ? 200 : 0); // 200 ≈ vibración media
  }

  delay(50);
}

// Función para convertir el string recibido en estados de motores
void parseMotorData(String data) {
  int idx = 0;
  int lastIndex = 0;
  for (int i = 0; i < 5; i++) {
    idx = data.indexOf(',', lastIndex);
    if (idx == -1) {
      motorStates[i] = data.substring(lastIndex).toInt();
      break;
    } else {
      motorStates[i] = data.substring(lastIndex, idx).toInt();
      lastIndex = idx + 1;
    }
  }
}