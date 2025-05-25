import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'delayed_animation.dart';
import 'login_page.dart';

class SocialPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(
          255,
          255,
          255,
          255,
        ).withOpacity(0),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: const Color.fromARGB(255, 0, 0, 0), // Colors.black
            size: 30,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            DelayedAnimation(
              delay: 1500,
              child: Container(
                height: 280,
                child: Image.asset('images/yoga_3.jpg'),
              ),
            ),
            DelayedAnimation(
              delay: 2500,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 30,
                ),
                child: Column(
                  children: [
                    Text(
                      "Le changement commence ici",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4CAF50), // Vert environnemental
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Connectez-vous pour surveiller votre environnement !",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(
                          255,
                          158,
                          158,
                          158,
                        ), // Colors.grey[500]
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DelayedAnimation(
              delay: 3500,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 40,
                ),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: const Color(
                          0xFF4CAF50,
                        ), // Vert environnemental
                        padding: const EdgeInsets.all(13),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login,
                            color: const Color.fromARGB(255, 255, 255, 255),
                          ), // Colors.white
                          const SizedBox(width: 10),
                          Text(
                            'Connexion',
                            style: GoogleFonts.poppins(
                              color: const Color.fromARGB(
                                255,
                                255,
                                255,
                                255,
                              ), // Colors.white
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
