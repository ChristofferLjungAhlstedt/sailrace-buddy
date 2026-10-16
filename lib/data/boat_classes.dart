/// The boat classes offered in the class dropdown.
///
/// To add a class, add a line to [boatClasses]. To add a logo later:
///  1. Put a PNG in assets/class_logos/ (e.g. j70.png)
///  2. Register the folder in pubspec.yaml:
///        flutter:
///          assets:
///            - assets/class_logos/
///  3. Set logoAsset: 'assets/class_logos/j70.png' on the class below.
/// (SVG logos would need the flutter_svg package, so PNG for now.)
class BoatClass {
  const BoatClass(this.name, {this.logoAsset});
  final String name;
  final String? logoAsset;
}

const List<BoatClass> boatClasses = [
  BoatClass('J70'),
  BoatClass('RS Feva'),
  BoatClass('Melges 24'),
  BoatClass('RS 21'),
];

/// Case-insensitive lookup. Returns null for free-text classes.
BoatClass? findBoatClass(String name) {
  final wanted = name.trim().toLowerCase();
  for (final c in boatClasses) {
    if (c.name.toLowerCase() == wanted) return c;
  }
  return null;
}

bool classHasLogo(String name) => findBoatClass(name)?.logoAsset != null;