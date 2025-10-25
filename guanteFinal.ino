/*
  Guante háptico con vibración proporcional
  - 5 sensores flex (A0–A4)
  - 5 motores vibradores (PWM: 3,5,6,9,10)
  - Vibración proporcional al cierre del dedo (>50%)
  - Serial envía flexión a Unity (solo lectura)
*/

const int NUM_DEDOS = 5;

// Pines sensores flex: pulgar, índice, medio, anular, meñique
const int flexPins[NUM_DEDOS] = {A0, A1, A2, A3, A5};

// Pines motores vibradores: pulgar, índice, medio, anular, meñique
const int motorPins[NUM_DEDOS] = {3, 5, 6, 9, 10};

// Valores de flexión leídos del sensor
int flexValues[NUM_DEDOS];

// Rango de flexión para empezar a vibrar (ajustable según sensor)
const int FLEX_START = 450; // valor donde empieza a vibrar
const int FLEX_END   = 300; // valor donde flexión máxima = 255 PWM

// Control de frecuencia de actualización
unsigned long lastUpdate = 0;
const int UPDATE_INTERVAL = 50; // ms (~20 Hz)

void setup() {
  Serial.begin(9600);

  // Configurar pines motores como salida y apagarlos
  for (int i = 0; i < NUM_DEDOS; i++) {
    pinMode(motorPins[i], OUTPUT);
    analogWrite(motorPins[i], 0);
  }
}

// Función para calcular intensidad de vibración según valor de flex
int calcularIntensidad(int valor) {
  if (valor < FLEX_START) {
    return constrain(map(valor, FLEX_START, FLEX_END, 0, 255), 0, 255);
  }
  return 0;
}

// Función para enviar los valores de flexión a Unity
void enviarFlexion() {
  for (int i = 0; i < NUM_DEDOS; i++) {
    Serial.print(flexValues[i]);
    if (i < NUM_DEDOS - 1) Serial.print(",");
  }
  Serial.println();
}

void loop() {
  // Control de frecuencia con millis() (no bloqueante)
  if (millis() - lastUpdate >= UPDATE_INTERVAL) {
    lastUpdate = millis();

    // Leer flexión de cada dedo
    for (int i = 0; i < NUM_DEDOS; i++) {
      flexValues[i] = analogRead(flexPins[i]);
    }

    // Enviar valores de flexión por Serial
    enviarFlexion();

    // Aplicar vibración proporcional
    for (int i = 0; i < NUM_DEDOS; i++) {
      int intensidad = calcularIntensidad(flexValues[i]);
      analogWrite(motorPins[i], intensidad);
    }
  }
}


