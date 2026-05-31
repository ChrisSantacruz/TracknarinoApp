// Este archivo proporciona una implementación global del método hashValues
// que es compatible con positioned_tap_detector_2 en Flutter moderno

// Parche para el método hashValues utilizado en TapPosition
int hashValues(dynamic a, dynamic b) {
  return Object.hash(a, b);
}
