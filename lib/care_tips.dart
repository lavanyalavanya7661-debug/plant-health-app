/// General first-step guidance per condition. Matched by keyword against the
/// model's condition name. This is general advice, not a diagnosis.
const Map<String, String> _tips = {
  'healthy':
      'The leaf looks healthy. Keep up regular watering, good sunlight and '
      'airflow, and keep checking leaves weekly.',
  'late blight':
      'Remove and destroy affected leaves or plants. Avoid overhead watering '
      'and improve airflow. Spreads fast in cool, wet weather, so act quickly '
      'and ask a local agriculture office about a suitable fungicide.',
  'early blight':
      'Remove spotted lower leaves, mulch the soil, avoid wetting foliage, and '
      'rotate crops next season. A suitable fungicide may help if it spreads.',
  'powdery mildew':
      'Improve airflow, avoid crowding plants and remove badly affected '
      'leaves. Sulfur or neem-based sprays are common first treatments.',
  'leaf mold':
      'Reduce humidity, space plants out and water at the base, not the '
      'leaves. Remove infected leaves.',
  'bacterial spot':
      'Avoid working with wet plants, remove infected leaves, and do not '
      'water overhead. Copper-based sprays are commonly used.',
  'rust':
      'Remove affected leaves, keep foliage dry and improve airflow. A '
      'suitable fungicide may be needed if it keeps spreading.',
  'scab':
      'Rake and destroy fallen leaves, prune for airflow and consider a '
      'fungicide program in the next season.',
  'mite':
      'Spray leaves (including undersides) with water or neem/soap solution '
      'and check again in a few days.',
  'virus':
      'No cure for viral diseases. Remove and destroy infected plants and '
      'control insects such as whiteflies and aphids that spread it.',
  // Generic matches go last so the specific ones above win first.
  'blight':
      'Remove and destroy affected leaves, avoid overhead watering, improve '
      'airflow and rotate crops. A suitable fungicide may help if it spreads.',
  'leaf spot':
      'Remove spotted leaves, keep foliage dry, space plants for airflow and '
      'clear fallen debris. Ask a local agriculture office if a fungicide is '
      'needed.',
};

const String _fallback =
    'Remove badly affected leaves, avoid wetting foliage, improve airflow, '
    'and take a close-up photo to your local agriculture extension office '
    'for confirmation before treating.';

String careTipFor(String condition) {
  final c = condition.toLowerCase();
  for (final entry in _tips.entries) {
    if (c.contains(entry.key)) return entry.value;
  }
  return _fallback;
}