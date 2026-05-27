import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/oportunidad_model.dart';
import '../../services/oportunidad_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/operational_empty_state.dart';
import '../../widgets/operational/operational_error_state.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../widgets/operational/premium_operational_widgets.dart';
import 'ruta_viaje_screen.dart';

class OportunidadesScreen extends StatefulWidget {
  final VoidCallback? onTripAccepted;

  const OportunidadesScreen({super.key, this.onTripAccepted});

  @override
  State<OportunidadesScreen> createState() => _OportunidadesScreenState();
}

class _OportunidadesScreenState extends State<OportunidadesScreen> {
  final _searchController = TextEditingController();
  List<Oportunidad> _oportunidades = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _statusFilter = 'todas';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _cargarOportunidades();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarOportunidades() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final oportunidades =
          await OportunidadService.obtenerOportunidadesDisponibles();
      if (!mounted) return;
      setState(() {
        _oportunidades = oportunidades;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudieron cargar las cargas disponibles. Revisa conexión o intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  List<Oportunidad> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _oportunidades.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.titulo.toLowerCase().contains(query) ||
          item.origen.toLowerCase().contains(query) ||
          item.destino.toLowerCase().contains(query) ||
          (item.tipoCarga ?? '').toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == 'todas' || item.estado == _statusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _cargarOportunidades,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (_, __) => const _OpportunitySkeleton(),
                ),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: OperationalErrorState(
                  message: _errorMessage!,
                  onRetry: _cargarOportunidades,
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: OperationalEmptyState(
                  icon: Icons.route_outlined,
                  title: 'Sin cargas para este filtro',
                  message:
                      'Cuando el backend publique oportunidades compatibles aparecerán aquí.',
                  actionLabel: 'Actualizar',
                  onAction: _cargarOportunidades,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                sliver: SliverList.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final oportunidad = _filtered[index];
                    return _OpportunityCard(
                      oportunidad: oportunidad,
                      onTap: () => _mostrarDetallesOportunidad(oportunidad),
                      onAccept: () => _aceptarCarga(oportunidad),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cargas disponibles',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Acepta cargas reales publicadas por contratistas. Sin métricas inventadas.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Buscar por origen, destino o carga',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todas',
                  value: 'todas',
                  group: _statusFilter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'Disponibles',
                  value: 'disponible',
                  group: _statusFilter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'Asignadas',
                  value: 'asignada',
                  group: _statusFilter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label: 'En ruta',
                  value: 'en_ruta',
                  group: _statusFilter,
                  onTap: _setFilter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setFilter(String value) {
    setState(() => _statusFilter = value);
  }

  void _replaceOpportunity(Oportunidad oportunidad) {
    setState(() {
      final index = _oportunidades.indexWhere(
        (item) => item.id == oportunidad.id,
      );
      if (index == -1) return;
      _oportunidades[index] = oportunidad;
    });
  }

  void _mostrarDetallesOportunidad(Oportunidad oportunidad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _OpportunityDetailsSheet(
          oportunidad: oportunidad,
          onUpdated: _replaceOpportunity,
          onAccept: () {
            Navigator.of(context).pop();
            _aceptarCarga(oportunidad);
          },
        );
      },
    );
  }

  Future<void> _aceptarCarga(Oportunidad oportunidad) async {
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AcceptTripSheet(oportunidad: oportunidad),
    );

    if (confirmar != true || oportunidad.id == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.emerald400),
          ),
    );

    try {
      final oportunidadAceptada = await OportunidadService.aceptarOportunidad(
        oportunidad.id!,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carga aceptada. Ruta preparada.')),
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => RutaViajeScreen(oportunidad: oportunidadAceptada),
        ),
      );

      widget.onTripAccepted?.call();
      _cargarOportunidades();
    } on TripActionQueuedException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      _cargarOportunidades();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      var mensaje = 'No se pudo aceptar la carga.';
      final raw = e.toString();
      if (raw.contains('Ya tienes un viaje activo')) {
        mensaje =
            'Ya tienes un viaje activo. Finaliza el viaje actual antes de aceptar otra carga.';
      } else if (raw.contains('ya fue aceptada')) {
        mensaje = 'Esta carga ya fue aceptada por otro camionero.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }
}

class _OpportunityCard extends StatelessWidget {
  final Oportunidad oportunidad;
  final VoidCallback onTap;
  final VoidCallback onAccept;

  const _OpportunityCard({
    required this.oportunidad,
    required this.onTap,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: _statusColor(oportunidad.estado).withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  oportunidad.titulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PremiumStatusPill(
                label: _statusLabel(oportunidad.estado),
                color: _statusColor(oportunidad.estado),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _RouteLine(origen: oportunidad.origen, destino: oportunidad.destino),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _publisherLabel(oportunidad),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _MetricChip(
                label: _money(oportunidad.precio),
                icon: Icons.payments_outlined,
              ),
              _MetricChip(
                label: _distance(oportunidad),
                icon: Icons.route_outlined,
              ),
              _MetricChip(
                label: _duration(oportunidad),
                icon: Icons.timer_outlined,
              ),
              if (oportunidad.tipoCarga != null)
                _MetricChip(
                  label: oportunidad.tipoCarga!,
                  icon: Icons.inventory_2_outlined,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTap,
                  child: const Text('Ver detalle'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed:
                      oportunidad.estado == 'disponible' ? onAccept : null,
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpportunityDetailsSheet extends StatelessWidget {
  final Oportunidad oportunidad;
  final ValueChanged<Oportunidad> onUpdated;
  final VoidCallback onAccept;

  const _OpportunityDetailsSheet({
    required this.oportunidad,
    required this.onUpdated,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: PremiumGlassCard(
        radius: 28,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumSheetHandle(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      oportunidad.titulo,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _RouteLine(
                origen: oportunidad.origen,
                destino: oportunidad.destino,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _MetricChip(
                    label: _money(oportunidad.precio),
                    icon: Icons.payments_outlined,
                  ),
                  _MetricChip(
                    label: _distance(oportunidad),
                    icon: Icons.route_outlined,
                  ),
                  _MetricChip(
                    label: _duration(oportunidad),
                    icon: Icons.timer_outlined,
                  ),
                  if (oportunidad.tipoCarga != null)
                    _MetricChip(
                      label: oportunidad.tipoCarga!,
                      icon: Icons.inventory_2_outlined,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _PublisherCard(oportunidad: oportunidad),
              if ((oportunidad.descripcion ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  oportunidad.descripcion!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.graphite300,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _NegotiationPanel(oportunidad: oportunidad, onUpdated: onUpdated),
              const SizedBox(height: AppSpacing.lg),
              PremiumPrimaryButton(
                label: 'Aceptar carga',
                icon: Icons.check_rounded,
                onPressed: oportunidad.estado == 'disponible' ? onAccept : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcceptTripSheet extends StatelessWidget {
  final Oportunidad oportunidad;

  const _AcceptTripSheet({required this.oportunidad});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      radius: 28,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PremiumSheetHandle(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Confirmar carga',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${oportunidad.origen} hacia ${oportunidad.destino}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.graphite300),
            ),
            const SizedBox(height: AppSpacing.md),
            _MetricChip(
              label: _money(oportunidad.precio),
              icon: Icons.payments_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublisherCard extends StatelessWidget {
  final Oportunidad oportunidad;

  const _PublisherCard({required this.oportunidad});

  @override
  Widget build(BuildContext context) {
    final contratista = oportunidad.contratistaInfo;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publicado por',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          PremiumInfoRow(
            icon: Icons.business_center_outlined,
            label: contratista?.empresa == null ? 'Persona' : 'Empresa',
            value: contratista?.empresa ?? contratista?.nombre ?? 'Contratista',
            color: AppColors.emerald400,
          ),
          PremiumInfoRow(
            icon: Icons.person_outline,
            label: 'Contacto',
            value: contratista?.nombre ?? 'No especificado',
          ),
          if ((contratista?.telefono ?? '').isNotEmpty)
            PremiumInfoRow(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: contratista!.telefono!,
              color: AppColors.statusSyncing,
            ),
        ],
      ),
    );
  }
}

class _NegotiationPanel extends StatefulWidget {
  final Oportunidad oportunidad;
  final ValueChanged<Oportunidad> onUpdated;

  const _NegotiationPanel({required this.oportunidad, required this.onUpdated});

  @override
  State<_NegotiationPanel> createState() => _NegotiationPanelState();
}

class _NegotiationPanelState extends State<_NegotiationPanel> {
  final _priceController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.oportunidad.precio.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _sendOffer() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0 || widget.oportunidad.id == null) {
      _showMessage('Ingresa una oferta válida.');
      return;
    }
    await _runAction(
      () => OportunidadService.enviarOfertaPrecio(
        oportunidadId: widget.oportunidad.id!,
        precioOfertado: price,
      ),
      'Oferta enviada al contratista.',
    );
  }

  Future<void> _cancelOffer() async {
    if (widget.oportunidad.id == null) return;
    await _runAction(
      () => OportunidadService.cancelarOfertaPrecio(widget.oportunidad.id!),
      'Oferta cancelada.',
    );
  }

  Future<void> _acceptCounterOffer() async {
    if (widget.oportunidad.id == null) return;
    await _runAction(
      () => OportunidadService.aceptarContraoferta(widget.oportunidad.id!),
      'Contraoferta aceptada. La carga quedó asignada.',
    );
  }

  Future<void> _runAction(
    Future<Oportunidad> Function() action,
    String successMessage,
  ) async {
    setState(() => _loading = true);
    try {
      final updated = await action();
      widget.onUpdated(updated);
      if (mounted) _showMessage(successMessage);
    } catch (e) {
      if (mounted) _showMessage('No se pudo completar la negociación.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final negotiation = widget.oportunidad.negociacion;
    final hasOffer = negotiation.estado == 'oferta_camionero';
    final hasCounterOffer = negotiation.estado == 'contraoferta_contratista';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Negociación de precio',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _negotiationText(negotiation),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            enabled: !_loading && !hasCounterOffer,
            decoration: const InputDecoration(
              labelText: 'Tu oferta COP',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const LinearProgressIndicator(minHeight: 3)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: hasCounterOffer ? _acceptCounterOffer : _sendOffer,
                  icon: Icon(
                    hasCounterOffer
                        ? Icons.check_circle_outline
                        : Icons.send_outlined,
                  ),
                  label: Text(
                    hasCounterOffer ? 'Aceptar contraoferta' : 'Enviar oferta',
                  ),
                ),
                if (hasOffer || hasCounterOffer)
                  OutlinedButton.icon(
                    onPressed: _cancelOffer,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar oferta'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _negotiationText(OpportunityNegotiation negotiation) {
    switch (negotiation.estado) {
      case 'oferta_camionero':
        return 'Oferta enviada: ${_money(negotiation.precioOfertado ?? widget.oportunidad.precio)}. Esperando respuesta del contratista.';
      case 'contraoferta_contratista':
        return 'Contraoferta recibida: ${_money(negotiation.precioContraoferta ?? widget.oportunidad.precio)}. Puedes aceptarla o cancelar.';
      case 'aceptada':
        return 'Negociación aceptada.';
      case 'cancelada':
        return 'La negociación fue cancelada. Puedes enviar una nueva oferta.';
      default:
        return 'Puedes proponer un precio diferente antes de aceptar la carga.';
    }
  }
}

class _RouteLine extends StatelessWidget {
  final String origen;
  final String destino;

  const _RouteLine({required this.origen, required this.destino});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _Dot(color: AppColors.emerald400),
            Container(
              width: 2,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 3),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            const _Dot(color: AppColors.alertCritical),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origen,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                destino,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetricChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.graphite300),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String group;
  final ValueChanged<String> onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(value),
      ),
    );
  }
}

class _OpportunitySkeleton extends StatelessWidget {
  const _OpportunitySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: PremiumGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OperationalSkeleton(height: 16, width: 220),
            SizedBox(height: AppSpacing.md),
            OperationalSkeleton(height: 12, width: double.infinity),
            SizedBox(height: AppSpacing.sm),
            OperationalSkeleton(height: 12, width: 180),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
        ],
      ),
    );
  }
}

Color _statusColor(String estado) {
  switch (estado) {
    case 'disponible':
      return AppColors.emerald400;
    case 'en_ruta':
      return AppColors.statusSyncing;
    case 'asignada':
    case 'aceptada':
      return AppColors.statusStale;
    default:
      return AppColors.graphite300;
  }
}

String _statusLabel(String estado) {
  switch (estado) {
    case 'disponible':
      return 'Disponible';
    case 'en_ruta':
      return 'En ruta';
    case 'asignada':
      return 'Asignada';
    case 'aceptada':
      return 'Aceptada';
    default:
      return estado;
  }
}

String _money(double value) => '\$${value.toStringAsFixed(0)}';

String _publisherLabel(Oportunidad oportunidad) {
  final contratista = oportunidad.contratistaInfo;
  final empresa = contratista?.empresa;
  final nombre = contratista?.nombre;
  if (empresa != null && empresa.isNotEmpty) {
    return 'Publicado por $empresa · $nombre';
  }
  return 'Publicado por ${nombre ?? 'contratista'}';
}

double? _calculatedDistanceKm(Oportunidad oportunidad) {
  final origin = oportunidad.origin;
  final destination = oportunidad.destination;
  if (origin == null || destination == null) return null;
  final distanceMeters = const Distance().as(
    LengthUnit.Meter,
    LatLng(origin.lat, origin.lng),
    LatLng(destination.lat, destination.lng),
  );
  return distanceMeters / 1000;
}

String _distance(Oportunidad oportunidad) {
  final value = oportunidad.distanciaKm;
  if (value != null) return '$value km';
  final calculated = _calculatedDistanceKm(oportunidad);
  return calculated == null
      ? 'Distancia pendiente'
      : '${calculated.toStringAsFixed(1)} km';
}

String _duration(Oportunidad oportunidad) {
  final value = oportunidad.duracionEstimadaHoras;
  if (value != null) return '$value h';
  final distance = _calculatedDistanceKm(oportunidad);
  if (distance == null) return 'ETA pendiente';
  const averageTruckSpeedKmh = 38;
  final minutes = (distance / averageTruckSpeedKmh * 60).round();
  if (minutes < 60) return '$minutes min';
  return '${(minutes / 60).toStringAsFixed(1)} h';
}
