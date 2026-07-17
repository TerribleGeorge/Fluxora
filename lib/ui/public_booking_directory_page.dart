import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/account.dart';
import '../domain/public_booking.dart';
import 'public_booking_page.dart';

class PublicBookingDirectoryPage extends StatefulWidget {
  const PublicBookingDirectoryPage({required this.repository, super.key});

  final PublicBookingRepository repository;

  @override
  State<PublicBookingDirectoryPage> createState() =>
      _PublicBookingDirectoryPageState();
}

class _PublicBookingDirectoryPageState
    extends State<PublicBookingDirectoryPage> {
  final _queryController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  Timer? _debounce;

  List<PublicBookingBusiness> _businesses = const [];
  bool _loading = true;
  String? _error;
  int _requestSequence = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final requestSequence = ++_requestSequence;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final businesses = await widget.repository.searchBusinesses(
        query: _queryController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
      );
      if (!mounted || requestSequence != _requestSequence) return;
      setState(() {
        _businesses = businesses;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestSequence != _requestSequence) return;
      setState(() {
        _loading = false;
        _error = error is PublicBookingFailure
            ? error.message
            : 'Não foi possível carregar os estabelecimentos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('public-booking-directory'),
      appBar: AppBar(title: const Text('Encontrar atendimento')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _search,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 18),
                      _buildFilters(),
                      const SizedBox(height: 18),
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_error != null)
                        _DirectoryMessage(
                          key: const ValueKey('public-directory-error'),
                          icon: Icons.cloud_off_outlined,
                          title: 'Busca indisponível',
                          message: _error!,
                          actionLabel: 'Tentar novamente',
                          onPressed: _search,
                        )
                      else if (_businesses.isEmpty)
                        const _DirectoryMessage(
                          key: ValueKey('public-directory-empty'),
                          icon: Icons.search_off_outlined,
                          title: 'Nenhum estabelecimento encontrado',
                          message:
                              'Tente buscar por outro serviço, bairro, cidade ou CEP.',
                        )
                      else
                        _buildResults(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.spa_outlined, color: colorScheme.onPrimaryContainer),
          const SizedBox(height: 14),
          Text(
            'Encontre um horário perto de você',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Busque por estabelecimento, serviço, cidade ou CEP e agende sem criar conta.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final fields = [
              TextField(
                key: const ValueKey('public-directory-query'),
                controller: _queryController,
                textInputAction: TextInputAction.search,
                onChanged: _scheduleSearch,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  labelText: 'Serviço ou estabelecimento',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              TextField(
                key: const ValueKey('public-directory-city'),
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                onChanged: _scheduleSearch,
                decoration: const InputDecoration(
                  labelText: 'Cidade',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              TextField(
                key: const ValueKey('public-directory-state'),
                controller: _stateController,
                textCapitalization: TextCapitalization.characters,
                onChanged: _scheduleSearch,
                maxLength: 2,
                decoration: const InputDecoration(labelText: 'UF'),
              ),
              TextField(
                key: const ValueKey('public-directory-postal-code'),
                controller: _postalCodeController,
                keyboardType: TextInputType.number,
                onChanged: _scheduleSearch,
                decoration: const InputDecoration(labelText: 'CEP'),
              ),
            ];
            if (!wide) {
              return Column(
                children: [
                  for (final field in fields) ...[
                    field,
                    if (field != fields.last) const SizedBox(height: 12),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: fields[0]),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: fields[1]),
                const SizedBox(width: 12),
                Expanded(child: fields[2]),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: fields[3]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_businesses.length} estabelecimento(s) encontrado(s)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (final business in _businesses) ...[
          _BusinessCard(
            business: business,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PublicBookingPage(
                  slug: business.slug,
                  repository: widget.repository,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business, required this.onTap});

  final PublicBookingBusiness business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        key: ValueKey('public-directory-business-${business.slug}'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Icon(_businessIcon(business.businessType)),
        ),
        title: Text(
          business.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              _businessTypeLabel(business.businessType),
              if (business.locationLabel.isNotEmpty) business.locationLabel,
              '${business.serviceCount} serviços',
              '${business.professionalCount} profissionais',
            ].join(' · '),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  static IconData _businessIcon(BusinessType type) {
    return switch (type) {
      BusinessType.barbershop => Icons.content_cut,
      BusinessType.nailStudio => Icons.brush_outlined,
      BusinessType.spa => Icons.spa_outlined,
      BusinessType.aestheticClinic => Icons.face_retouching_natural_outlined,
      _ => Icons.storefront_outlined,
    };
  }

  static String _businessTypeLabel(BusinessType type) {
    return switch (type) {
      BusinessType.barbershop => 'Barbearia',
      BusinessType.beautySalon => 'Salão de beleza',
      BusinessType.nailStudio => 'Manicure e pedicure',
      BusinessType.browAndLashStudio => 'Cílios e sobrancelhas',
      BusinessType.makeupStudio => 'Maquiagem',
      BusinessType.spa => 'Spa',
      BusinessType.aestheticClinic => 'Estética',
      BusinessType.otherBeauty => 'Beleza e bem-estar',
    };
  }
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
