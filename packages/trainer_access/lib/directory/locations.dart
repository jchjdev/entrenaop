/// Catálogo INE de provincias; los nombres visibles incluyen variantes habituales.
/// https://www.ine.es/daco/daco42/codmun/cod_provincia.htm
class DirectoryProvince {
  const DirectoryProvince(this.code, this.name, [this.islands = const []]);
  final String code, name;
  final List<String> islands;
}

const directoryProvinces = [
  DirectoryProvince('15', 'A Coruña'),
  DirectoryProvince('01', 'Álava / Araba'),
  DirectoryProvince('02', 'Albacete'),
  DirectoryProvince('03', 'Alicante / Alacant'),
  DirectoryProvince('04', 'Almería'),
  DirectoryProvince('33', 'Asturias'),
  DirectoryProvince('05', 'Ávila'),
  DirectoryProvince('06', 'Badajoz'),
  DirectoryProvince('07', 'Illes Balears / Baleares', [
    'Formentera',
    'Ibiza',
    'Mallorca',
    'Menorca',
  ]),
  DirectoryProvince('08', 'Barcelona'),
  DirectoryProvince('48', 'Bizkaia'),
  DirectoryProvince('09', 'Burgos'),
  DirectoryProvince('10', 'Cáceres'),
  DirectoryProvince('11', 'Cádiz'),
  DirectoryProvince('39', 'Cantabria'),
  DirectoryProvince('12', 'Castellón / Castelló'),
  DirectoryProvince('51', 'Ceuta'),
  DirectoryProvince('13', 'Ciudad Real'),
  DirectoryProvince('14', 'Córdoba'),
  DirectoryProvince('16', 'Cuenca'),
  DirectoryProvince('20', 'Gipuzkoa'),
  DirectoryProvince('17', 'Girona'),
  DirectoryProvince('18', 'Granada'),
  DirectoryProvince('19', 'Guadalajara'),
  DirectoryProvince('21', 'Huelva'),
  DirectoryProvince('22', 'Huesca'),
  DirectoryProvince('23', 'Jaén'),
  DirectoryProvince('26', 'La Rioja'),
  DirectoryProvince('35', 'Las Palmas', [
    'Fuerteventura',
    'Gran Canaria',
    'Lanzarote',
    'La Graciosa',
  ]),
  DirectoryProvince('24', 'León'),
  DirectoryProvince('25', 'Lleida'),
  DirectoryProvince('27', 'Lugo'),
  DirectoryProvince('28', 'Madrid'),
  DirectoryProvince('29', 'Málaga'),
  DirectoryProvince('52', 'Melilla'),
  DirectoryProvince('30', 'Murcia'),
  DirectoryProvince('31', 'Navarra'),
  DirectoryProvince('32', 'Ourense'),
  DirectoryProvince('34', 'Palencia'),
  DirectoryProvince('36', 'Pontevedra'),
  DirectoryProvince('37', 'Salamanca'),
  DirectoryProvince('38', 'Santa Cruz de Tenerife', [
    'La Gomera',
    'El Hierro',
    'La Palma',
    'Tenerife',
  ]),
  DirectoryProvince('40', 'Segovia'),
  DirectoryProvince('41', 'Sevilla'),
  DirectoryProvince('42', 'Soria'),
  DirectoryProvince('43', 'Tarragona'),
  DirectoryProvince('44', 'Teruel'),
  DirectoryProvince('45', 'Toledo'),
  DirectoryProvince('46', 'Valencia / València'),
  DirectoryProvince('47', 'Valladolid'),
  DirectoryProvince('49', 'Zamora'),
  DirectoryProvince('50', 'Zaragoza'),
];

DirectoryProvince? directoryProvince(String code) {
  for (final province in directoryProvinces) {
    if (province.code == code) return province;
  }
  return null;
}
