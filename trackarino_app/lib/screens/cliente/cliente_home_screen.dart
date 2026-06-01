import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/oportunidad_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/oportunidad_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/operational_empty_state.dart';
import '../../widgets/operational/operational_error_state.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../widgets/operational/premium_operational_widgets.dart';
import '../contratista/crear_oportunidad_screen.dart';
import '../contratista/seguimiento_screen.dart';

class ClienteHomeScreen extends StatefulWidget {
  final User usuario;

  const ClienteHomeScreen({super.key, required this.usuario});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;
  List<Oportunidad> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await OportunidadService.obtenerOportunidadesCliente();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar tus cargas: $error';
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final hasActiveLoad = _trips.any(
      (trip) =>
          !['entregada', 'cancelada'].contains(trip.estado) && !trip.finalizada,
    );
    if (hasActiveLoad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Como cliente solo puedes tener una carga activa a la vez.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CrearOportunidadScreen()));
    if (mounted) _loadTrips();
  }

  Future<void> _openOffers(Oportunidad trip) async {
    if (trip.id == null) return;
    final updated = await showModalBottomSheet<Oportunidad>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OffersSheet(trip: trip),
    );
    if (updated != null && mounted) {
      setState(() {
        final index = _trips.indexWhere((item) => item.id == updated.id);
        if (index >= 0) _trips[index] = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _DashboardTab(
        loading: _loading,
        error: _error,
        trips: _trips,
        onRefresh: _loadTrips,
        onOpenOffers: _openOffers,
      ),
      SeguimientoScreen(onTripCompleted: _loadTrips),
      _HistoryTab(trips: _trips),
      _ProfileTab(usuario: widget.usuario),
    ];

    return PremiumGradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Cliente TrackNariño'),
          actions: [
            IconButton(
              onPressed: () => context.read<AuthService>().logout(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        floatingActionButton:
            _selectedIndex == 0
                ? FloatingActionButton.extended(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear carga'),
                )
                : null,
        body: tabs[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected:
              (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Cargas',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Oportunidad> trips;
  final Future<void> Function() onRefresh;
  final void Function(Oportunidad trip) onOpenOffers;

  const _DashboardTab({
    required this.loading,
    required this.error,
    required this.trips,
    required this.onRefresh,
    required this.onOpenOffers,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: OperationalSkeleton(),
      );
    }
    if (error != null) {
      return OperationalErrorState(message: error!, onRetry: onRefresh);
    }
    if (trips.isEmpty) {
      return const OperationalEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Aún no tienes cargas',
        message: 'Crea tu primera carga para recibir ofertas de camioneros.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemBuilder: (context, index) {
          final trip = trips[index];
          return _TripCard(trip: trip, onOpenOffers: () => onOpenOffers(trip));
        },
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemCount: trips.length,
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Oportunidad trip;
  final VoidCallback onOpenOffers;

  const _TripCard({required this.trip, required this.onOpenOffers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ownerLabel =
        trip.ownerType == 'CLIENTE'
            ? 'Publicado por Cliente'
            : 'Publicado por Contratista';

    return PremiumGlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.titulo,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$ownerLabel · ${trip.estado}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.emerald400,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${trip.origen} → ${trip.destino}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.graphite200,
            ),
          ),
          if (trip.incentivoPrioridad > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Bono por prioridad: \$${trip.incentivoPrioridad.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.statusStale,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Monitoreo: ${trip.camioneroAsignado == null ? 'esperando transportista' : 'transportista asignado'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.graphite300,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '\$${trip.precio.toStringAsFixed(0)} COP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onOpenOffers,
                child: const Text('Ver ofertas'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OffersSheet extends StatefulWidget {
  final Oportunidad trip;

  const _OffersSheet({required this.trip});

  @override
  State<_OffersSheet> createState() => _OffersSheetState();
}

class _OffersSheetState extends State<_OffersSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final offers = await OportunidadService.listarOfertas(widget.trip.id!);
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las ofertas: $error';
        _loading = false;
      });
    }
  }

  Future<void> _accept(String offerId) async {
    final updated = await OportunidadService.aceptarOferta(offerId);
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  Future<void> _reject(String offerId) async {
    await OportunidadService.rechazarOferta(offerId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ofertas recibidas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (!_loading && _offers.isEmpty)
              const Text('Aún no hay ofertas para esta carga.'),
            for (final offer in _offers)
              _OfferTile(offer: offer, onAccept: _accept, onReject: _reject),
          ],
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Future<void> Function(String offerId) onAccept;
  final Future<void> Function(String offerId) onReject;

  const _OfferTile({
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final camionero = offer['camionero'];
    final camioneroName =
        camionero is Map
            ? (camionero['nombre'] ?? 'Camionero').toString()
            : 'Camionero';
    final camioneroTelefono =
        camionero is Map ? camionero['telefono']?.toString() : null;
    final camion =
        camionero is Map && camionero['camion'] is Map
            ? camionero['camion'] as Map
            : null;
    final offerId = (offer['_id'] ?? offer['id']).toString();
    final estado = (offer['estado'] ?? 'pendiente').toString();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(camioneroName),
      subtitle: Text(
        [
          '${offer['precio']} COP',
          estado,
          if (camioneroTelefono != null) camioneroTelefono,
          if (camion != null)
            '${camion['tipoVehiculo'] ?? 'Vehículo'} ${camion['placa'] ?? ''}'
                .trim(),
        ].join(' · '),
      ),
      trailing:
          estado == 'pendiente'
              ? Wrap(
                spacing: AppSpacing.xs,
                children: [
                  TextButton(
                    onPressed: () => onReject(offerId),
                    child: const Text('Rechazar'),
                  ),
                  FilledButton(
                    onPressed: () => onAccept(offerId),
                    child: const Text('Aceptar'),
                  ),
                ],
              )
              : null,
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<Oportunidad> trips;

  const _HistoryTab({required this.trips});

  @override
  Widget build(BuildContext context) {
    final completed =
        trips.where((trip) => trip.estado == 'entregada').toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Viajes realizados: ${completed.length}'),
        const SizedBox(height: AppSpacing.md),
        for (final trip in completed)
          ListTile(title: Text(trip.titulo), subtitle: Text(trip.destino)),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final User usuario;

  const _ProfileTab({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: PremiumGlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              usuario.nombre,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              usuario.correo,
              style: const TextStyle(color: AppColors.graphite300),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Cliente · ${usuario.calificacion?.toStringAsFixed(1) ?? 'Sin calificaciones'}',
              style: const TextStyle(color: AppColors.emerald400),
            ),
          ],
        ),
      ),
    );
  }
}
