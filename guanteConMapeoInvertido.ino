/*
  Guante de flexión - Mapeo correcto (0° extendido, 90° flexionado)
  - Vibración proporcional a la flexión
  - Umbral para evitar vibraciones leves
  - Inversión por canal si el sensor lee al revés
  - Calibración extendida y ganancia para aprovechar todo el rango
*/

#define NUM_CH 3
const uint8_t flexPins[NUM_CH]  = {A0, A1, A2};

#define USE_MOTORS
#ifdef USE_MOTORS
const uint8_t motorPins[NUM_CH] = {3, 5, 6};
#endif

// Invertir orientación por canal: true si en extensión lee ~90° en vez de ~0°
const bool INVERT_CH[NUM_CH] = { true, true, true }; // ajustar por canal

const uint16_t SEND_PERIOD_MS = 20; // ~50 Hz
const float ANG_MIN = 0.0f;
const float ANG_MAX = 90.0f;

const float EMA_ALPHA   = 0.25f;
const float GAMMA_CURVE = 0.8f;   // más cerca de 1.0 para no perder amplitud
const float ENV_ATTACK  = 0.55f;
const float ENV_RELEASE = 0.03f;

const uint32_t CALIB_MS = 5000;   // calibración más larga (5 s)
const float ANG_THRESHOLD = 20.0f; // vibra solo si ángulo > 20°
const float NORM_GAIN = 1.2f;     // ganancia post-normalización

uint16_t rawADC[NUM_CH]   = {0};
float    ema[NUM_CH]      = {0};
uint16_t rawMin[NUM_CH]   = {1023,1023,1023};
uint16_t rawMax[NUM_CH]   = {0,0,0};
float    env[NUM_CH]      = {0};

bool     calibrated       = false;
uint32_t tStartCalib      = 0;
uint32_t tLastSend        = 0;

static inline float constrain01(float x){ return x < 0 ? 0 : (x > 1 ? 1 : x); }
float applyGamma(float x, float g){ return powf(constrain01(x), g); }

float followEnv(float in, float &state){
  float k = (in > state) ? ENV_ATTACK : ENV_RELEASE;
  state += k * (in - state);
  return state;
}

float normalizeAuto(uint16_t raw, uint8_t ch){
  if (!calibrated){
    if (raw < rawMin[ch]) rawMin[ch] = raw;
    if (raw > rawMax[ch]) rawMax[ch] = raw;
  }
  int span = (int)rawMax[ch] - (int)rawMin[ch];
  if (span < 50) span = 50; // span mínimo mayor para evitar rangos diminutos
  float n = (raw - rawMin[ch]) / (float)span;
  return constrain01(n);
}

float normToDegrees(float n){
  return ANG_MIN + n * (ANG_MAX - ANG_MIN);
}

void resetCalibration(){
  for (uint8_t i=0;i<NUM_CH;i++){
    rawMin[i] = 1023;
    rawMax[i] = 0;
  }
  calibrated = false;
  tStartCalib = millis();
  Serial.println(F("Recalibrando..."));
}

void setup(){
  Serial.begin(115200);
  for (uint8_t i=0;i<NUM_CH;i++){
    pinMode(flexPins[i], INPUT);
    #ifdef USE_MOTORS
      pinMode(motorPins[i], OUTPUT);
      analogWrite(motorPins[i], 0);
    #endif
  }
  resetCalibration();
}

void loop(){
  while (Serial.available()){
    char c = Serial.read();
    if (c=='C' || c=='c'){
      resetCalibration();
    }
  }

  for (uint8_t i=0;i<NUM_CH;i++){
    uint16_t r = analogRead(flexPins[i]);
    rawADC[i] = r;
    ema[i] = (1.0f - EMA_ALPHA) * ema[i] + EMA_ALPHA * (float)r;
    if (!calibrated && (millis() - tStartCalib >= CALIB_MS)){
      calibrated = true;
    }
  }

  uint32_t now = millis();
  if (now - tLastSend >= SEND_PERIOD_MS){
    tLastSend = now;

    float deg[NUM_CH];
    uint8_t pwm[NUM_CH];

    for (uint8_t i=0;i<NUM_CH;i++){
      float n  = normalizeAuto((uint16_t)ema[i], i);

      // Ganancia para aprovechar todo el rango
      n *= NORM_GAIN;
      if (n > 1.0f) n = 1.0f;

      float cg = applyGamma(n, GAMMA_CURVE);
      float e  = followEnv(cg, env[i]);

      // Corregir orientación si el sensor lee invertido
      float eMap = INVERT_CH[i] ? (1.0f - e) : e;

      // Ángulo final: 0° extendido, 90° flexionado
      float a  = normToDegrees(eMap);

      // PWM proporcional a la flexión
      int p = (int)(eMap * 255.0f);

      // Umbral: no vibra si ángulo < ANG_THRESHOLD
      if (a < ANG_THRESHOLD) p = 0;

      if (p < 0) p = 0; else if (p > 255) p = 255;

      deg[i] = a;
      pwm[i] = (uint8_t)p;

      #ifdef USE_MOTORS
        analogWrite(motorPins[i], pwm[i]);
      #endif
    }

    // Telemetría
    Serial.print(F("F"));
    for (uint8_t i=0;i<NUM_CH;i++){
      Serial.print(',');
      Serial.print(rawADC[i]);
    }
    Serial.print('\n');

    Serial.print(F("A"));
    for (uint8_t i=0;i<NUM_CH;i++){
      Serial.print(',');
      Serial.print((int)deg[i]);
    }
    Serial.print('\n');
  }
}
