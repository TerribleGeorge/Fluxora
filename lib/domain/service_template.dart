import 'account.dart';

class ServiceTemplate {
  const ServiceTemplate({
    required this.name,
    required this.category,
    required this.durationMinutes,
    this.suggestedPrice = 0,
  });

  final String name;
  final String category;
  final int durationMinutes;
  final double suggestedPrice;

  bool matches(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return true;
    return _normalize(name).contains(normalized) ||
        _normalize(category).contains(normalized);
  }
}

class ServiceTemplateCatalog {
  const ServiceTemplateCatalog._();

  static List<ServiceTemplate> forBusinessType(BusinessType type) {
    final base = switch (type) {
      BusinessType.barbershop => _barbershop,
      BusinessType.beautySalon => _beautySalon,
      BusinessType.nailStudio => _nailStudio,
      BusinessType.browAndLashStudio => _browAndLashStudio,
      BusinessType.makeupStudio => _makeupStudio,
      BusinessType.spa => _spa,
      BusinessType.aestheticClinic => _aestheticClinic,
      BusinessType.otherBeauty => _generalBeauty,
    };
    return [...base, ..._shared].toList(growable: false);
  }

  static final _barbershop = [
    ServiceTemplate(
      name: 'Corte masculino',
      category: 'Cabelo',
      durationMinutes: 40,
    ),
    ServiceTemplate(
      name: 'Corte infantil',
      category: 'Cabelo',
      durationMinutes: 35,
    ),
    ServiceTemplate(
      name: 'Corte degradê',
      category: 'Cabelo',
      durationMinutes: 45,
    ),
    ServiceTemplate(
      name: 'Corte social',
      category: 'Cabelo',
      durationMinutes: 35,
    ),
    ServiceTemplate(
      name: 'Corte navalhado',
      category: 'Cabelo',
      durationMinutes: 50,
    ),
    ServiceTemplate(
      name: 'Corte e barba',
      category: 'Combo',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Barba completa',
      category: 'Barba',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Barba com toalha quente',
      category: 'Barba',
      durationMinutes: 40,
    ),
    ServiceTemplate(
      name: 'Aparar barba',
      category: 'Barba',
      durationMinutes: 20,
    ),
    ServiceTemplate(
      name: 'Pigmentação de barba',
      category: 'Barba',
      durationMinutes: 35,
    ),
    ServiceTemplate(
      name: 'Sobrancelha na navalha',
      category: 'Sobrancelhas',
      durationMinutes: 10,
    ),
    ServiceTemplate(
      name: 'Relaxamento masculino',
      category: 'Química',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Progressiva masculina',
      category: 'Química',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Hidratação capilar',
      category: 'Tratamento',
      durationMinutes: 25,
    ),
    ServiceTemplate(
      name: 'Hidratação de barba',
      category: 'Tratamento',
      durationMinutes: 20,
    ),
  ];

  static final _beautySalon = [
    ServiceTemplate(
      name: 'Corte feminino',
      category: 'Cabelo',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Corte infantil',
      category: 'Cabelo',
      durationMinutes: 40,
    ),
    ServiceTemplate(
      name: 'Escova',
      category: 'Finalização',
      durationMinutes: 45,
    ),
    ServiceTemplate(
      name: 'Escova modelada',
      category: 'Finalização',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Penteado',
      category: 'Finalização',
      durationMinutes: 75,
    ),
    ServiceTemplate(
      name: 'Coloração raiz',
      category: 'Coloração',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Coloração global',
      category: 'Coloração',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Tonalização',
      category: 'Coloração',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Mechas',
      category: 'Coloração',
      durationMinutes: 180,
    ),
    ServiceTemplate(name: 'Luzes', category: 'Coloração', durationMinutes: 180),
    ServiceTemplate(
      name: 'Morena iluminada',
      category: 'Coloração',
      durationMinutes: 210,
    ),
    ServiceTemplate(
      name: 'Balayage',
      category: 'Coloração',
      durationMinutes: 210,
    ),
    ServiceTemplate(
      name: 'Progressiva',
      category: 'Química',
      durationMinutes: 180,
    ),
    ServiceTemplate(
      name: 'Botox capilar',
      category: 'Tratamento',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Hidratação capilar',
      category: 'Tratamento',
      durationMinutes: 45,
    ),
    ServiceTemplate(
      name: 'Nutrição capilar',
      category: 'Tratamento',
      durationMinutes: 45,
    ),
    ServiceTemplate(
      name: 'Reconstrução capilar',
      category: 'Tratamento',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Cronograma capilar',
      category: 'Tratamento',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Alongamento capilar',
      category: 'Extensão',
      durationMinutes: 240,
    ),
    ServiceTemplate(
      name: 'Manutenção de alongamento',
      category: 'Extensão',
      durationMinutes: 150,
    ),
  ];

  static final _nailStudio = [
    ServiceTemplate(name: 'Manicure', category: 'Mãos', durationMinutes: 45),
    ServiceTemplate(name: 'Pedicure', category: 'Pés', durationMinutes: 60),
    ServiceTemplate(
      name: 'Manicure e pedicure',
      category: 'Combo',
      durationMinutes: 100,
    ),
    ServiceTemplate(
      name: 'Esmaltação simples',
      category: 'Esmaltação',
      durationMinutes: 25,
    ),
    ServiceTemplate(
      name: 'Esmaltação em gel',
      category: 'Esmaltação',
      durationMinutes: 50,
    ),
    ServiceTemplate(
      name: 'Remoção de esmalte em gel',
      category: 'Remoção',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Blindagem de unhas',
      category: 'Tratamento',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Banho de gel',
      category: 'Alongamento',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Alongamento em gel',
      category: 'Alongamento',
      durationMinutes: 150,
    ),
    ServiceTemplate(
      name: 'Alongamento em fibra de vidro',
      category: 'Alongamento',
      durationMinutes: 180,
    ),
    ServiceTemplate(
      name: 'Manutenção de alongamento',
      category: 'Manutenção',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Reposição de unha',
      category: 'Manutenção',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Nail art simples',
      category: 'Nail art',
      durationMinutes: 20,
    ),
    ServiceTemplate(
      name: 'Nail art elaborada',
      category: 'Nail art',
      durationMinutes: 45,
    ),
    ServiceTemplate(name: 'Spa dos pés', category: 'Pés', durationMinutes: 75),
    ServiceTemplate(
      name: 'Podologia estética',
      category: 'Pés',
      durationMinutes: 60,
    ),
  ];

  static final _browAndLashStudio = [
    ServiceTemplate(
      name: 'Design de sobrancelhas',
      category: 'Sobrancelhas',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Design com henna',
      category: 'Sobrancelhas',
      durationMinutes: 45,
    ),
    ServiceTemplate(
      name: 'Design com tintura',
      category: 'Sobrancelhas',
      durationMinutes: 45,
    ),
    ServiceTemplate(
      name: 'Brow lamination',
      category: 'Sobrancelhas',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Micropigmentação fio a fio',
      category: 'Micropigmentação',
      durationMinutes: 150,
    ),
    ServiceTemplate(
      name: 'Retoque de micropigmentação',
      category: 'Micropigmentação',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Remoção de micropigmentação',
      category: 'Micropigmentação',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Extensão de cílios clássico',
      category: 'Cílios',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Extensão de cílios volume brasileiro',
      category: 'Cílios',
      durationMinutes: 150,
    ),
    ServiceTemplate(
      name: 'Extensão de cílios volume russo',
      category: 'Cílios',
      durationMinutes: 180,
    ),
    ServiceTemplate(
      name: 'Manutenção de cílios',
      category: 'Cílios',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Remoção de cílios',
      category: 'Cílios',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Lash lifting',
      category: 'Cílios',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Coloração de cílios',
      category: 'Cílios',
      durationMinutes: 30,
    ),
  ];

  static final _makeupStudio = [
    ServiceTemplate(
      name: 'Maquiagem social',
      category: 'Maquiagem',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Maquiagem festa',
      category: 'Maquiagem',
      durationMinutes: 75,
    ),
    ServiceTemplate(
      name: 'Maquiagem noiva',
      category: 'Noivas',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Prévia de noiva',
      category: 'Noivas',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Maquiagem madrinha',
      category: 'Maquiagem',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Maquiagem formanda',
      category: 'Maquiagem',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Maquiagem editorial',
      category: 'Editorial',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Maquiagem artística',
      category: 'Artística',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Penteado social',
      category: 'Penteado',
      durationMinutes: 75,
    ),
    ServiceTemplate(
      name: 'Penteado noiva',
      category: 'Noivas',
      durationMinutes: 120,
    ),
    ServiceTemplate(
      name: 'Aplicação de cílios postiços',
      category: 'Cílios',
      durationMinutes: 20,
    ),
  ];

  static final _spa = [
    ServiceTemplate(
      name: 'Massagem relaxante',
      category: 'Massagem',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Massagem terapêutica',
      category: 'Massagem',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Drenagem linfática',
      category: 'Corporal',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Drenagem pós-operatória',
      category: 'Corporal',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Massagem modeladora',
      category: 'Corporal',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Reflexologia',
      category: 'Massagem',
      durationMinutes: 45,
    ),
    ServiceTemplate(name: 'Spa day', category: 'Pacotes', durationMinutes: 240),
    ServiceTemplate(
      name: 'Banho de lua',
      category: 'Corporal',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Esfoliação corporal',
      category: 'Corporal',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Hidratação corporal',
      category: 'Corporal',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Limpeza de pele',
      category: 'Facial',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Revitalização facial',
      category: 'Facial',
      durationMinutes: 60,
    ),
  ];

  static final _aestheticClinic = [
    ServiceTemplate(
      name: 'Avaliação estética',
      category: 'Avaliação',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Limpeza de pele',
      category: 'Facial',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Peeling químico',
      category: 'Facial',
      durationMinutes: 45,
    ),
    ServiceTemplate(
      name: 'Peeling de diamante',
      category: 'Facial',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Microagulhamento',
      category: 'Facial',
      durationMinutes: 90,
    ),
    ServiceTemplate(
      name: 'Radiofrequência facial',
      category: 'Facial',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Radiofrequência corporal',
      category: 'Corporal',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Criolipólise',
      category: 'Corporal',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Depilação a laser - buço',
      category: 'Depilação a laser',
      durationMinutes: 15,
    ),
    ServiceTemplate(
      name: 'Depilação a laser - axilas',
      category: 'Depilação a laser',
      durationMinutes: 20,
    ),
    ServiceTemplate(
      name: 'Depilação a laser - virilha',
      category: 'Depilação a laser',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Depilação a laser - pernas',
      category: 'Depilação a laser',
      durationMinutes: 60,
    ),
    ServiceTemplate(name: 'Botox', category: 'Injetáveis', durationMinutes: 45),
    ServiceTemplate(
      name: 'Preenchimento labial',
      category: 'Injetáveis',
      durationMinutes: 60,
    ),
    ServiceTemplate(
      name: 'Bioestimulador de colágeno',
      category: 'Injetáveis',
      durationMinutes: 60,
    ),
  ];

  static final _generalBeauty = [
    ..._beautySalon,
    ..._nailStudio,
    ..._browAndLashStudio,
    ..._makeupStudio,
  ];

  static final _shared = [
    ServiceTemplate(
      name: 'Depilação buço',
      category: 'Depilação',
      durationMinutes: 15,
    ),
    ServiceTemplate(
      name: 'Depilação axilas',
      category: 'Depilação',
      durationMinutes: 20,
    ),
    ServiceTemplate(
      name: 'Depilação meia perna',
      category: 'Depilação',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Depilação perna completa',
      category: 'Depilação',
      durationMinutes: 45,
    ),
    ServiceTemplate(
      name: 'Depilação virilha',
      category: 'Depilação',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Depilação rosto',
      category: 'Depilação',
      durationMinutes: 30,
    ),
    ServiceTemplate(
      name: 'Pacote personalizado',
      category: 'Pacotes',
      durationMinutes: 60,
    ),
  ];
}

String _normalize(String value) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString().toLowerCase().trim();
}
