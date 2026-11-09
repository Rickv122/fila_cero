abstract final class S {
  static const appName = 'FilaCero',
      subtitle = 'Sabe dónde hay combustible antes de salir';
  static const visitor = 'Entrar sin cuenta',
      login = 'Iniciar sesión',
      register = 'Crear cuenta',
      guest = 'Modo visitante',
      profile = 'Mi perfil',
      map = 'Mapa',
      list = 'Surtidores',
      admin = 'Administración',
      back = 'Volver',
      logout = 'Cerrar sesión',
      enter = 'Entrar',
      save = 'Guardar surtidor';
  static const localAccount = 'Tu cuenta en FilaCero',
      localHelp = 'Completa tus datos para continuar.';
  static const name = 'Nombre',
      email = 'Correo electrónico',
      password = 'Contraseña',
      confirm = 'Confirmar contraseña',
      showPassword = 'Mostrar u ocultar contraseña';
  static const nameError = 'Escribe al menos 2 caracteres',
      emailError = 'Escribe un correo válido',
      passwordError = 'Usa al menos 8 caracteres',
      confirmError = 'Las contraseñas no coinciden',
      loginError = 'Correo o contraseña incorrectos',
      duplicate = 'Este correo ya está registrado',
      storageError = 'No se pudo guardar. Intenta nuevamente.';
  static const report = 'Reportar',
      loginRequired = 'Inicia sesión',
      loginMessage =
          'Necesitas iniciar sesión para reportar el estado de un surtidor.',
      futureReport = 'Esta función estará disponible próximamente.',
      ok = 'Entendido';
  static const status = [
    'Hay combustible',
    'Poco combustible',
    'No hay combustible',
    'Sin reportes vigentes',
  ];
  static const mapCredit = '© OpenStreetMap',
      legend = 'Estados del surtidor',
      details = 'Detalle del surtidor',
      address = 'Dirección',
      city = 'Ciudad',
      fuels = 'Combustibles',
      latest = 'Último reporte',
      noReports = 'Sin reportes todavía',
      expired = 'Reporte sin vigencia',
      reportAuthor = 'Actualizado';
  static const noStations = 'Todavía no hay surtidores registrados',
      viewDetails = 'Ver detalle',
      readonly = 'Puedes consultar el mapa y los detalles sin crear cuenta.',
      accountRole = 'Conductor',
      adminRole = 'Administrador',
      adminHelp = 'Agrega y actualiza los surtidores.',
      add = 'Agregar surtidor',
      edit = 'Editar surtidor',
      stationName = 'Nombre del surtidor',
      latitude = 'Latitud',
      longitude = 'Longitud',
      required = 'Completa este campo',
      latitudeError = 'Ingresa una latitud entre -90 y 90',
      longitudeError = 'Ingresa una longitud entre -180 y 180',
      fuelError = 'Selecciona al menos un combustible',
      saved = 'Surtidor guardado',
      cancel = 'Cancelar',
      location = 'Ubicación',
      coordinateHelp = 'Ingresa las coordenadas del surtidor.',
      permissions = 'Solo el administrador puede modificar surtidores.',
      fuelOptions = ['Especial', 'Premium', 'Diésel', 'GNV'];
  static String ago(DateTime time) {
    final mins = DateTime.now().difference(time).inMinutes.clamp(0, 999999);
    return mins < 1
        ? 'Hace un momento'
        : mins < 60
        ? 'Hace $mins minutos'
        : 'Hace ${mins ~/ 60} horas';
  }

  static String date(DateTime time) =>
      '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
