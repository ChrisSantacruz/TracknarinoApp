class User {
  final String? id;
  final String nombre;
  final String correo;
  final String? telefono;
  final String tipoUsuario;
  final String? empresa;
  final String? empresaAfiliada;
  final String? numeroCedula;
  final Map<String, dynamic>? camion;
  final String? metodoPago;
  final String? authProvider;
  final String? fotoPerfil;
  final bool rolConfigurado;
  final bool isDisponible;
  final double? calificacion;
  final int? viajesCompletados;
  final String? sessionType;
  final bool isSimulation;

  User({
    this.id,
    required this.nombre,
    required this.correo,
    this.telefono,
    required this.tipoUsuario,
    this.empresa,
    this.empresaAfiliada,
    this.numeroCedula,
    this.camion,
    this.metodoPago,
    this.authProvider,
    this.fotoPerfil,
    this.rolConfigurado = true,
    this.isDisponible = false,
    this.calificacion,
    this.viajesCompletados,
    this.sessionType,
    this.isSimulation = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      nombre: json['nombre'] ?? '',
      correo: json['correo'] ?? '',
      telefono: json['telefono'],
      tipoUsuario: json['tipoUsuario'] ?? '',
      empresa: json['empresa'],
      empresaAfiliada: json['empresaAfiliada'],
      numeroCedula: json['numeroCedula'],
      camion: json['camion'] != null 
          ? Map<String, dynamic>.from(json['camion']) 
          : null,
      metodoPago: json['metodoPago'],
      authProvider: json['authProvider'],
      fotoPerfil: json['fotoPerfil'],
      rolConfigurado: json['rolConfigurado'] ?? (json['tipoUsuario'] != 'usuario'),
      isDisponible: json['isDisponible'] ?? false,
      calificacion: json['calificacion']?.toDouble(),
      viajesCompletados: json['viajesCompletados'],
      sessionType: json['sessionType'],
      isSimulation:
          json['isSimulation'] == true ||
          json['sessionType'] == 'SIMULATION_DRIVER',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'correo': correo,
      if (telefono != null) 'telefono': telefono,
      'tipoUsuario': tipoUsuario,
      if (empresa != null) 'empresa': empresa,
      if (empresaAfiliada != null) 'empresaAfiliada': empresaAfiliada,
      if (numeroCedula != null) 'numeroCedula': numeroCedula,
      if (camion != null) 'camion': camion,
      if (metodoPago != null) 'metodoPago': metodoPago,
      if (authProvider != null) 'authProvider': authProvider,
      if (fotoPerfil != null) 'fotoPerfil': fotoPerfil,
      'rolConfigurado': rolConfigurado,
      'isDisponible': isDisponible,
      if (calificacion != null) 'calificacion': calificacion,
      if (viajesCompletados != null) 'viajesCompletados': viajesCompletados,
      if (sessionType != null) 'sessionType': sessionType,
      'isSimulation': isSimulation,
    };
  }

  User copyWith({
    String? nombre,
    String? telefono,
    String? empresa,
    String? metodoPago,
    String? tipoUsuario,
    String? authProvider,
    String? fotoPerfil,
    bool? rolConfigurado,
    Map<String, dynamic>? camion,
    bool? isDisponible,
    double? calificacion,
    int? viajesCompletados,
    String? sessionType,
    bool? isSimulation,
  }) {
    return User(
      id: id,
      nombre: nombre ?? this.nombre,
      correo: correo,
      telefono: telefono ?? this.telefono,
      tipoUsuario: tipoUsuario ?? this.tipoUsuario,
      empresa: empresa ?? this.empresa,
      empresaAfiliada: empresaAfiliada,
      numeroCedula: numeroCedula,
      camion: camion ?? this.camion,
      metodoPago: metodoPago ?? this.metodoPago,
      authProvider: authProvider ?? this.authProvider,
      fotoPerfil: fotoPerfil ?? this.fotoPerfil,
      rolConfigurado: rolConfigurado ?? this.rolConfigurado,
      isDisponible: isDisponible ?? this.isDisponible,
      calificacion: calificacion ?? this.calificacion,
      viajesCompletados: viajesCompletados ?? this.viajesCompletados,
      sessionType: sessionType ?? this.sessionType,
      isSimulation: isSimulation ?? this.isSimulation,
    );
  }
} 