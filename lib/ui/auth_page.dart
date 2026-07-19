import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/auth_bloc.dart';
import '../state/auth_event.dart';
import '../state/auth_state.dart';

enum _AuthMode { ownerSignIn, employeeSignIn, signUp, reset }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeBusinessEmailController = TextEditingController();
  final _employeeNameController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthMode _mode = _AuthMode.ownerSignIn;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeBusinessEmailController.dispose();
    _employeeNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: BlocConsumer<AuthBloc, AuthState>(
                    listenWhen: (previous, current) =>
                        current.message != null &&
                        current.message != previous.message,
                    listener: (context, state) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(state.message!)));
                    },
                    builder: (context, state) {
                      return AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.auto_awesome, size: 42),
                            const SizedBox(height: 16),
                            Text(
                              _title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 28),
                            if (_mode == _AuthMode.ownerSignIn ||
                                _mode == _AuthMode.employeeSignIn) ...[
                              SegmentedButton<_AuthMode>(
                                segments: const [
                                  ButtonSegment<_AuthMode>(
                                    value: _AuthMode.ownerSignIn,
                                    icon: Icon(Icons.storefront_outlined),
                                    label: Text('Proprietário'),
                                  ),
                                  ButtonSegment<_AuthMode>(
                                    value: _AuthMode.employeeSignIn,
                                    icon: Icon(Icons.badge_outlined),
                                    label: Text('Funcionário'),
                                  ),
                                ],
                                selected: {_mode},
                                onSelectionChanged: (selection) =>
                                    _changeMode(selection.single),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (_mode == _AuthMode.signUp) ...[
                              TextField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  labelText: 'Seu nome',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_mode == _AuthMode.employeeSignIn) ...[
                              TextField(
                                controller: _employeeBusinessEmailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'E-mail do estabelecimento',
                                  helperText:
                                      'Use o e-mail de login informado pelo dono.',
                                  prefixIcon: Icon(Icons.storefront_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _employeeNameController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  labelText: 'Nome cadastrado',
                                  helperText:
                                      'Digite como o dono cadastrou seu acesso.',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              ),
                            ] else
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: _mode == _AuthMode.reset
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                onSubmitted: _mode == _AuthMode.reset
                                    ? (_) => _submit()
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                              ),
                            if (_mode != _AuthMode.reset) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  helperText: _mode == _AuthMode.signUp
                                      ? 'Use pelo menos 8 caracteres'
                                      : _mode == _AuthMode.employeeSignIn
                                      ? 'Senha definida pelo dono do estabelecimento'
                                      : null,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: state.loading ? null : _submit,
                              child: state.loading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_primaryLabel),
                            ),
                            const SizedBox(height: 12),
                            if (_mode == _AuthMode.ownerSignIn)
                              TextButton(
                                onPressed: () => _changeMode(_AuthMode.reset),
                                child: const Text('Esqueci minha senha'),
                              ),
                            if (_mode == _AuthMode.employeeSignIn)
                              Text(
                                'Se esqueceu a senha, peça para o dono redefinir no cadastro do funcionário.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            TextButton(
                              onPressed: () => _changeMode(
                                _mode == _AuthMode.ownerSignIn
                                    ? _AuthMode.signUp
                                    : _AuthMode.ownerSignIn,
                              ),
                              child: Text(
                                _mode == _AuthMode.ownerSignIn
                                    ? 'Criar minha conta'
                                    : 'Voltar para o acesso',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (_mode) {
    _AuthMode.ownerSignIn => 'Bem-vindo ao Fluxora',
    _AuthMode.employeeSignIn => 'Acesso do funcionário',
    _AuthMode.signUp => 'Crie seu acesso',
    _AuthMode.reset => 'Recupere sua senha',
  };

  String get _subtitle => switch (_mode) {
    _AuthMode.ownerSignIn => 'A gestão do seu negócio de beleza começa aqui.',
    _AuthMode.employeeSignIn =>
      'Entre somente na agenda e nas tarefas liberadas para você.',
    _AuthMode.signUp => 'Organize sua equipe, caixa e lucro real.',
    _AuthMode.reset => 'Enviaremos um link seguro para o seu e-mail.',
  };

  String get _primaryLabel => switch (_mode) {
    _AuthMode.ownerSignIn => 'Entrar como proprietário',
    _AuthMode.employeeSignIn => 'Entrar como funcionário',
    _AuthMode.signUp => 'Criar conta',
    _AuthMode.reset => 'Enviar instruções',
  };

  void _changeMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _passwordController.clear();
    });
  }

  void _submit() {
    final bloc = context.read<AuthBloc>();
    switch (_mode) {
      case _AuthMode.ownerSignIn:
        bloc.add(
          AuthSignInRequested(_emailController.text, _passwordController.text),
        );
      case _AuthMode.employeeSignIn:
        bloc.add(
          AuthEmployeeSignInRequested(
            businessEmail: _employeeBusinessEmailController.text,
            professionalName: _employeeNameController.text,
            password: _passwordController.text,
          ),
        );
      case _AuthMode.signUp:
        bloc.add(
          AuthSignUpRequested(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
          ),
        );
      case _AuthMode.reset:
        bloc.add(AuthPasswordResetRequested(_emailController.text));
    }
  }
}
