import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'delayed_animation.dart';
import 'social_page.dart';

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fond blanc uniforme
      body: Container(
        margin: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DelayedAnimation(
              delay: 1500,
              child: Container(
                height: 150,
                child: Image.asset('images/tos.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            DelayedAnimation(
              delay: 2500,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color:
                      Colors.white, // Fond blanc pour le conteneur de l'image
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset('images/yoga_1.jpg', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 30),
            DelayedAnimation(
              delay: 3500,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: AnimatedTextKit(
                  animatedTexts: [
                    TyperAnimatedText(
                      "Bienvenue sur Kivi !",
                      textStyle: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 158, 158, 158),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      speed: const Duration(milliseconds: 100),
                    ),
                    TyperAnimatedText(
                      "Avec Kivi, surveillez, analysez et comprenez en temps réel la qualité de votre environnement pour un cadre de vie plus sain et sécurisé.",
                      textStyle: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 158, 158, 158),
                        fontSize: 16,
                      ),
                      speed: const Duration(milliseconds: 100),
                    ),
                  ],
                  totalRepeatCount: 1,
                  displayFullTextOnTap: true,
                  stopPauseOnTap: true,
                ),
              ),
            ),
            DelayedAnimation(
              delay: 4500,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.all(20),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  child: const Text(
                    'Démarrer',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SocialPage()),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
