import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String _selectedVehicle = 'Gbaka';

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final rawEmail = _emailController.text.trim();
    final email = rawEmail.isEmpty ? '$phone@transitci.com' : rawEmail;
    final pass = _passwordController.text;

    if (name.isEmpty || (phone.isEmpty && rawEmail.isEmpty) || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Remplissez tous les champs obligatoires'),
      ));
      return;
    }

    setState(() => _loading = true);
    late String message;
    bool success = false;
    try {
      // Sign up user with Supabase Auth using email or phone
      final res = rawEmail.isNotEmpty
          ? await Supabase.instance.client.auth.signUp(
              email: email,
              password: pass,
            )
          : await Supabase.instance.client.auth.signUp(
              phone: phone,
              password: pass,
            );

      final user = res.user;
      if (user == null) {
        message = 'Inscription initiée. Vérifiez votre e-mail ou SMS.';
      } else {
        message = 'Inscription réussie ! Connectez-vous.';
      }
      success = true;

      // Insert minimal chauffeur profile (best-effort)
      try {
        await Supabase.instance.client.from('chauffeurs').insert({
          'id': user?.id ?? phone,
          'nom': name,
          'telephone': phone,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    } catch (e) {
      message = e is AuthException ? e.message : e.toString();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inscription : $message')));
    if (success) {
      Navigator.pushReplacementNamed(context, '/chauffeur/login');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B00),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 255, 255, 0.15),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Devenir partenaire',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Rejoignez Transit CI dès aujourd’hui',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInputField(
                            controller: _nameController,
                            label: 'Nom complet',
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            controller: _emailController,
                            label: 'Adresse email',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            controller: _phoneController,
                            label: 'Numéro de téléphone',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            controller: _passwordController,
                            label: 'Mot de passe',
                            icon: Icons.lock,
                            obscureText: _obscure,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF9E9E9E),
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Type de véhicule',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF232323),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.85,
                            children: [
                              _buildVehicleOption('Gbaka', Icons.directions_bus),
                              _buildVehicleOption('Warren', Icons.directions_car),
                              _buildVehicleOption('Woro-Woro', Icons.directions_bus_filled),
                              _buildVehicleOption('SOTRA', Icons.directions_bus),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B00),
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
                                  )
                                : const Text(
                                    'Créer mon compte',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Déjà inscrit ?',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF606060)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacementNamed(context, '/chauffeur/login'),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                                  child: const Text(
                                    'Se connecter',
                                    style: TextStyle(
                                      color: Color(0xFFFF6B00),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF9E9E9E)),
        hintText: label,
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _buildVehicleOption(String name, IconData icon) {
    final selected = _selectedVehicle == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedVehicle = name),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFFF6B00) : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? const Color(0xFFFF6B00) : const Color(0xFF6B6B6B),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? const Color(0xFFFF6B00) : const Color(0xFF4F4F4F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

