import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Perfil'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: Color(0xFF29150D),
                    foregroundColor: Color(0xFFFF8A50),
                    child: Icon(Icons.person_rounded, size: 42),
                  ),
                  const SizedBox(height: 22),
                  const Card(
                    color: Color(0xFF171717),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Objetivo y disponibilidad'),
                          subtitle: Text('Se configurará desde Mi plan.'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.workspace_premium_outlined),
                          title: Text('Plan actual'),
                          subtitle: Text('Free'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
