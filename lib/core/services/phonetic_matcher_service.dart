import 'dart:math';
import 'dart:typed_data';

class MatchEvaluation {
  final bool isPass;
  final double score; // 0.0 a 100.0
  final String feedback;

  const MatchEvaluation({
    required this.isPass,
    required this.score,
    required this.feedback,
  });
}

class PhoneticMatcherService {
  PhoneticMatcherService._();

  static const int sampleRate = 16000;
  static const int numMelFilters = 20;
  static const int numCepstralCoeffs = 12; // Formantes puros (c1 a c12, ignorando c0)

  static double _hzToMel(double hz) => 2595.0 * log(1.0 + hz / 700.0) / ln10;
  static double _melToHz(double mel) => 700.0 * (pow(10.0, mel / 2595.0) - 1.0);

  /// Convierte los bytes de un WAV PCM 16-bit mono a valores numéricos [-1.0, 1.0]
  static List<double> bytesToSamples(Uint8List bytes) {
    if (bytes.length < 44) return [];
    
    // Ignoramos el encabezado estándar de 44 bytes de archivos WAV
    final ByteData byteData = ByteData.sublistView(bytes, 44);
    final int count = byteData.lengthInBytes ~/ 2;

    List<double> samples = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      samples[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  /// Extrae vectores acústicos independientes del tono/pitch y del volumen
  static List<List<double>> extractFeatureVectors(
    List<double> samples, {
    int frameSize = 512,
    int hopSize = 256,
  }) {
    if (samples.length < frameSize) return [];

    // 1. Preénfasis para balancear altas frecuencias
    final preEmphasized = List<double>.filled(samples.length, 0.0);
    preEmphasized[0] = samples[0];
    for (int i = 1; i < samples.length; i++) {
      preEmphasized[i] = samples[i] - 0.97 * samples[i - 1];
    }

    // 2. Bancos de filtros Mel (300Hz a 4000Hz: rango del habla humana)
    final double minMel = _hzToMel(300.0);
    final double maxMel = _hzToMel(4000.0);
    final double melStep = (maxMel - minMel) / (numMelFilters + 1);

    List<double> filterCenters = List.generate(numMelFilters + 2, (i) => _melToHz(minMel + i * melStep));
    List<int> binIndices = filterCenters.map((hz) => (hz * frameSize / sampleRate).floor()).toList();

    List<List<double>> featureFrames = [];

    for (int start = 0; start + frameSize <= preEmphasized.length; start += hopSize) {
      // Ventana Hamming
      List<double> windowed = List.filled(frameSize, 0.0);
      for (int i = 0; i < frameSize; i++) {
        final double window = 0.54 - 0.46 * cos((2 * pi * i) / (frameSize - 1));
        windowed[i] = preEmphasized[start + i] * window;
      }

      // Transformada y espectro de potencia
      final int halfSize = frameSize ~/ 2;
      List<double> powerSpectrum = List.filled(halfSize, 0.0);
      for (int k = 0; k < halfSize; k++) {
        double real = 0.0, imag = 0.0;
        for (int n = 0; n < frameSize; n++) {
          final double angle = -2.0 * pi * k * n / frameSize;
          real += windowed[n] * cos(angle);
          imag += windowed[n] * sin(angle);
        }
        powerSpectrum[k] = (real * real + imag * imag) / frameSize;
      }

      // Filtrado Mel
      List<double> melEnergies = List.filled(numMelFilters, 0.0);
      for (int m = 1; m <= numMelFilters; m++) {
        final int left = binIndices[m - 1];
        final int center = binIndices[m];
        final int right = binIndices[m + 1];

        for (int k = left; k < center && k < halfSize; k++) {
          melEnergies[m - 1] += powerSpectrum[k] * (k - left) / (center - left);
        }
        for (int k = center; k < right && k < halfSize; k++) {
          melEnergies[m - 1] += powerSpectrum[k] * (right - k) / (right - center);
        }
      }

      // DCT: omitimos c0 para que el volumen no afecte
      List<double> mfcc = List.filled(numCepstralCoeffs, 0.0);
      for (int i = 1; i <= numCepstralCoeffs; i++) {
        double sum = 0.0;
        for (int j = 0; j < numMelFilters; j++) {
          final double logEnergy = log(max(melEnergies[j], 1e-6));
          sum += logEnergy * cos(pi * i * (j + 0.5) / numMelFilters);
        }
        mfcc[i - 1] = sum;
      }
      featureFrames.add(mfcc);
    }

    if (featureFrames.isEmpty) return [];

    // 3. Normalización Cepstral Media (CMVN): elimina el pitch (grave vs agudo)
    for (int c = 0; c < numCepstralCoeffs; c++) {
      double mean = 0.0;
      for (int f = 0; f < featureFrames.length; f++) {
        mean += featureFrames[f][c];
      }
      mean /= featureFrames.length;

      for (int f = 0; f < featureFrames.length; f++) {
        featureFrames[f][c] -= mean;
      }
    }

    return featureFrames;
  }

  static double _euclideanDistance(List<double> v1, List<double> v2) {
    double sum = 0.0;
    for (int i = 0; i < v1.length; i++) {
      final double diff = v1[i] - v2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  /// Alineación temporal de secuencias fonéticas con Dynamic Time Warping
  static double computeDtwDistance(List<List<double>> seq1, List<List<double>> seq2) {
    final int n = seq1.length;
    final int m = seq2.length;

    if (n == 0 || m == 0) return double.infinity;

    final dtw = List.generate(
      n + 1,
      (_) => List<double>.filled(m + 1, double.infinity),
    );
    dtw[0][0] = 0.0;

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final double cost = _euclideanDistance(seq1[i - 1], seq2[j - 1]);
        dtw[i][j] = cost + [
          dtw[i - 1][j],
          dtw[i][j - 1],
          dtw[i - 1][j - 1],
        ].reduce(min);
      }
    }

    return dtw[n][m] / (n + m);
  }

  /// Evalúa el audio del usuario contra el audio nativo guardado
  static MatchEvaluation compare({
    required Uint8List nativeWavBytes,
    required Uint8List userWavBytes,
    double passThreshold = 60.0,
  }) {
    final nativeSamples = bytesToSamples(nativeWavBytes);
    final userSamples = bytesToSamples(userWavBytes);

    final nativeFeatures = extractFeatureVectors(nativeSamples);
    final userFeatures = extractFeatureVectors(userSamples);

    if (userFeatures.isEmpty || userSamples.isEmpty) {
      return const MatchEvaluation(
        isPass: false,
        score: 0.0,
        feedback: "No se captó audio. Hablá más cerca del micrófono.",
      );
    }

    final double distance = computeDtwDistance(nativeFeatures, userFeatures);

    // Mapeo: distancias menores a 1.2 son excelentes coincidencias
    // Distancias mayores a 3.4 corresponden a fonemas claramente distintos
    final double rawScore = (1.0 - (distance / 3.4)) * 100.0;
    final double score = rawScore.clamp(0.0, 100.0);
    final bool isPass = score >= passThreshold;

    String feedback;
    if (score >= 85) {
      feedback = "¡Naiski! Pronunciación auténtica y clara.";
    } else if (isPass) {
      feedback = "¡Muy bien! Se entiende claramente.";
    } else if (score >= 40) {
      feedback = "Estuviste cerca. Prestá atención a las pausas y sonidos finales.";
    } else {
      feedback = "No sonó muy parecido. Escuchá el audio y probá otra vez.";
    }

    return MatchEvaluation(
      isPass: isPass,
      score: double.parse(score.toStringAsFixed(1)),
      feedback: feedback,
    );
  }
}