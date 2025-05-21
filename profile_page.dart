import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Ces couleurs restent inchangées
const Color primaryColor = Color(0xFF0088FF); // Bleu vif
const Color secondaryColor = Color(0xFF00D2FF); // Bleu cyan
const Color accentColor = Color(0xFF00E5FF); // Cyan lumineux
const Color darkColor = Color(0xFF121212); // Presque noir
const Color backgroundColor = Color(0xFF0A1929); // Bleu très foncé
const Color cardColor = Color(0xFF162033); // Bleu-gris foncé

final darkGradient = LinearGradient(
  colors: [darkColor, backgroundColor],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs pour tous les champs requis
  final _nameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(); // Nouveau contrôleur pour téléphone
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();
  
  bool _notificationsEnabled = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isProfileSaved = false; // Pour afficher le surnom et nom/prénom après sauvegarde
  
  File? _imageFile; // Pour stocker l'image de profil sélectionnée temporairement
  String? _imagePathInPrefs; // Pour stocker le chemin de l'image dans les préférences

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstNameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose(); // Libérer le contrôleur du téléphone
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtenir l'utilisateur actuel
      User? currentUser = _auth.currentUser;
      
      if (currentUser != null) {
        // Récupérer les données de l'utilisateur depuis Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _nameController.text = userData['nom'] ?? '';
            _firstNameController.text = userData['prenom'] ?? '';
            _nicknameController.text = userData['surnom'] ?? '';
            _emailController.text = userData['email'] ?? '';
            _phoneController.text = userData['telephone'] ?? ''; // Charger le téléphone
            _cityController.text = userData['ville'] ?? '';
            _notificationsEnabled = userData['notifications_enabled'] ?? true;
            _imagePathInPrefs = userData['photo_profil_path']; // Chemin local de l'image
            _isProfileSaved = true; // Activer l'affichage du surnom si les données sont chargées
            
            // Charger l'image depuis le chemin stocké si disponible
            if (_imagePathInPrefs != null && _imagePathInPrefs!.isNotEmpty) {
              final file = File(_imagePathInPrefs!);
              if (file.existsSync()) {
                _imageFile = file;
              }
            }
          });
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des données: $e");
      _showErrorSnackBar('Erreur lors du chargement du profil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Réduit la taille de l'image
        maxHeight: 512, // Réduit la taille de l'image
        imageQuality: 70, // Compression pour réduire la taille
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Erreur lors de la sélection de l'image: $e");
      _showErrorSnackBar('Erreur lors de la sélection de l\'image');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _saveUserData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Obtenir l'utilisateur actuel
        User? currentUser = _auth.currentUser;
        
        if (currentUser != null) {
          // Préparation des données à sauvegarder
          Map<String, dynamic> userData = {
            'nom': _nameController.text,
            'prenom': _firstNameController.text,
            'surnom': _nicknameController.text,
            'email': _emailController.text,
            'telephone': _phoneController.text, // Ajouter le téléphone
            'ville': _cityController.text,
            'notifications_enabled': _notificationsEnabled,
            'derniere_mise_a_jour': FieldValue.serverTimestamp(),
          };

          // Ajouter le chemin de l'image si disponible
          if (_imageFile != null) {
            userData['photo_profil_path'] = _imageFile!.path;
          }
          
          // Mise à jour du mot de passe si fourni
          if (_passwordController.text.isNotEmpty) {
            try {
              await currentUser.updatePassword(_passwordController.text);
            } catch (e) {
              print("Erreur lors de la mise à jour du mot de passe: $e");
              // Continue même si le mot de passe n'a pas pu être mis à jour
            }
          }
          
          // Mise à jour de l'email si changé
          if (_emailController.text != currentUser.email) {
            try {
              await currentUser.updateEmail(_emailController.text);
            } catch (e) {
              print("Erreur lors de la mise à jour de l'email: $e");
              // Continue même si l'email n'a pas pu être mis à jour
            }
          }
          
          // Mise à jour des données dans Firestore
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .update(userData);
          
          if (mounted) {
            // Afficher le dialogue de confirmation
            _showSaveConfirmationDialog();
            
            // Activer l'affichage du surnom et nom/prénom
            setState(() {
              _isProfileSaved = true;
            });
          }
        }
      } catch (e) {
        print("Erreur lors de la sauvegarde des données: $e");
        _showErrorSnackBar('Erreur lors de la sauvegarde: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSaveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: primaryColor),
              SizedBox(width: 10),
              Text(
                'Profil mis à jour',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            'Vos informations de profil ont été mises à jour avec succès et enregistrées dans la base de données.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(color: accentColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profil'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: darkGradient,
        ),
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: kToolbarHeight),
                    
                    // Avatar avec possibilité de modification
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  secondaryColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: _imageFile != null
                                ? CircleAvatar(
                                    radius: 60,
                                    backgroundColor: backgroundColor,
                                    backgroundImage: FileImage(_imageFile!),
                                  )
                                : CircleAvatar(
                                    radius: 60,
                                    backgroundColor: backgroundColor,
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: primaryColor,
                                    ),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Affichage du surnom, nom et prénom après sauvegarde
                    if (_isProfileSaved && _nicknameController.text.isNotEmpty) ...[
                      SizedBox(height: 15),
                      Center(
                        child: Text(
                          _nicknameController.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      Center(
                        child: Text(
                          "${_firstNameController.text} ${_nameController.text}",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 30),
                    
                    // Réorganisation des champs dans l'ordre spécifié
                    
                    // Nom
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nom',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre nom';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Prénom
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'Prénom',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre prénom';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Surnom
                    _buildTextField(
                      controller: _nicknameController,
                      label: 'Surnom',
                      icon: Icons.face,
                      validator: null, // Optionnel
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Email
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre email';
                        }
                        if (!value.contains('@')) {
                          return 'Veuillez entrer un email valide';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Téléphone (Nouveau champ)
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Téléphone (Optionnel)',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: null, // Optionnel
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Mot de passe
                    _buildPasswordField(
                      controller: _passwordController,
                      label: 'Mot de passe',
                      isObscured: _obscurePassword,
                      toggleObscured: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      validator: (value) {
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Confirmer mot de passe
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirmer mot de passe',
                      isObscured: _obscureConfirmPassword,
                      toggleObscured: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      validator: (value) {
                        if (_passwordController.text.isNotEmpty) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez confirmer votre mot de passe';
                          }
                          if (value != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Ville
                    _buildTextField(
                      controller: _cityController,
                      label: 'Ville',
                      icon: Icons.location_city,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre ville';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Notifications
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: SwitchListTile(
                        title: Row(
                          children: [
                            Icon(
                              Icons.notifications,
                              color: accentColor,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Notifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: Text(
                            'Recevoir des alertes sur la qualité de l\'air',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        value: _notificationsEnabled,
                        onChanged: (bool value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                        },
                        activeColor: primaryColor,
                        activeTrackColor: accentColor.withOpacity(0.5),
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade800,
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // Bouton sauvegarder
                    ElevatedButton(
                      onPressed: _saveUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: primaryColor.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 10),
                          Text(
                            'Sauvegarder mes infos de profil',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: accentColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback toggleObscured,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        obscureText: isObscured,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.lock, color: accentColor),
          suffixIcon: IconButton(
            icon: Icon(
              isObscured ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
            ),
            onPressed: toggleObscured,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        validator: validator,
      ),
    );
  }
}