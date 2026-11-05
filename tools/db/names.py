# Nombres y apellidos por grupo lingüístico para generar jugadores genéricos (ficticios).
POOLS = {
 "es": ("Alejandro Andrés Ángel Carlos Cristian Daniel David Diego Eduardo Emiliano Enzo Facundo Felipe Fernando Franco Gabriel Gonzalo Hugo Iván Javier Joaquín Jorge José Juan Julián Leandro Lucas Luis Manuel Marcos Martín Mateo Matías Miguel Nahuel Nicolás Óscar Pablo Pedro Rafael Ramiro Raúl Ricardo Rodrigo Santiago Sebastián Sergio Tomás Valentín Víctor",
        "Acosta Aguilar Alonso Álvarez Arias Benítez Blanco Bravo Cabrera Campos Castillo Castro Cruz Delgado Díaz Domínguez Duarte Escobar Espinoza Fernández Figueroa Flores Fuentes Gallardo García Gómez González Gutiérrez Guzmán Herrera Hernández Ibarra Jiménez Lara León López Lozano Luna Martínez Medina Méndez Molina Morales Moreno Muñoz Navarro Núñez Ortega Ortiz Pacheco Paredes Pérez Ramírez Ramos Reyes Ríos Rivas Rivera Robles Rodríguez Rojas Romero Ruiz Salas Sánchez Santos Serrano Silva Soto Suárez Torres Valdez Vargas Vázquez Vega Velázquez Vidal Villalba"),
 "pt": ("Gabriel Lucas Matheus Pedro Guilherme Rafael Felipe Bruno Thiago Vinícius Diego Gustavo André João Rodrigo Caio Igor Leonardo Marcelo Renan Wesley Danilo Éverton Fábio Hugo Luís Nuno Rúben Tiago Gonçalo Diogo Ricardo Vitor Wellington Alisson Murilo",
        "Silva Santos Oliveira Souza Pereira Costa Rodrigues Almeida Nascimento Lima Araújo Fernandes Carvalho Gomes Martins Rocha Ribeiro Alves Monteiro Mendes Barros Freitas Barbosa Pinto Moura Cavalcanti Dias Castro Campos Cardoso Teixeira Correia Moreira Nunes Vieira Lopes Fonseca Batista Coelho Machado"),
 "en": ("James Harry Jack Oliver Charlie George Thomas Daniel Joshua Ryan Callum Lewis Jordan Kyle Connor Liam Ethan Mason Tyler Jake Luke Adam Ben Sam Joe Aaron Marcus Nathan Owen Reece Jamie Kieran Declan Scott Dylan",
        "Smith Jones Taylor Brown Williams Wilson Johnson Davies Robinson Wright Thompson Evans Walker White Roberts Green Hall Wood Jackson Clarke Hughes Edwards Turner Hill Cooper Ward Morris King Baker Harris Lewis Bennett Murray Kelly Campbell Stewart Reid Fraser Hamilton"),
 "it": ("Alessandro Andrea Antonio Davide Federico Francesco Gianluca Giorgio Giovanni Lorenzo Luca Marco Matteo Mattia Nicolò Paolo Pietro Riccardo Roberto Simone Stefano Tommaso Valerio Daniele Fabio Emanuele Gabriele Leonardo",
        "Rossi Russo Ferrari Esposito Bianchi Romano Colombo Ricci Marino Greco Bruno Gallo Conti De Luca Mancini Costa Giordano Rizzo Lombardi Moretti Barbieri Fontana Santoro Mariani Rinaldi Caruso Ferrara Galli Martini Leone Longo Gentile Martinelli Vitale Serra Coppola De Santis"),
 "de": ("Lukas Leon Finn Jonas Paul Felix Maximilian Tim Niklas Jan Tom Moritz Julian Florian Kevin Marco Dennis Sebastian Fabian Philipp Tobias Stefan Robin Kai Lennart Nico Marvin Jannik",
        "Müller Schmidt Schneider Fischer Weber Meyer Wagner Becker Schulz Hoffmann Koch Richter Klein Wolf Schröder Neumann Schwarz Zimmermann Braun Krüger Hofmann Hartmann Lange Werner Krause Lehmann Köhler Maier Huber Kaiser Fuchs Peters Lang Scholz Möller Weiß Jung Hahn Vogel"),
 "fr": ("Lucas Hugo Louis Gabriel Théo Nathan Mathis Enzo Maxime Antoine Thomas Alexandre Clément Romain Julien Kylian Baptiste Quentin Valentin Florian Adrien Mehdi Yanis Rayan Ilan Bastien Corentin",
        "Martin Bernard Dubois Thomas Robert Richard Petit Durand Leroy Moreau Simon Laurent Lefebvre Michel Garcia David Bertrand Roux Vincent Fournier Morel Girard André Mercier Dupont Lambert Bonnet François Martinez Legrand Garnier Faure Rousseau Blanc Guerin Muller Henry"),
 "nl": ("Daan Sem Lars Luuk Milan Thijs Bram Jesse Ruben Tim Joris Stijn Niels Kevin Dennis Jasper Wout Arne Robbe Jens Senne Mats Bas Jelle",
        "de_Jong de_Vries van_den_Berg van_Dijk Bakker Janssen Visser Smit Meijer de_Boer Mulder de_Groot Bos Vos Peters Hendriks van_Leeuwen Dekker Brouwer de_Wit Dijkstra Smits de_Graaf van_der_Meer Peeters Maes Jacobs Willems Claes Goossens Wouters De_Smet Mertens"),
 "tr": ("Mehmet Mustafa Ahmet Ali Hüseyin Hasan İbrahim Murat Emre Burak Yusuf Kerem Arda Oğuz Cenk Volkan Ozan Serkan Kaan Berkay Barış Onur Uğur Eren Alp Rustam Timur Azamat Daniyar Sherzod",
        "Yılmaz Kaya Demir Şahin Çelik Yıldız Yıldırım Öztürk Aydın Özdemir Arslan Doğan Kılıç Aslan Çetin Kara Koç Kurt Özkan Şimşek Polat Korkmaz Erdoğan Güler Tekin Aksoy Karimov Tashkentov Nurmagambetov Abdullaev"),
 "ar": ("Mohamed Ahmed Ali Omar Youssef Karim Hamza Amine Mehdi Bilal Hassan Hussein Ibrahim Khalid Salem Tariq Walid Yassine Nabil Sami Faisal Abdullah Majed Saud Reza Ali-Reza Mehdi Sardar Ehsan Navid",
        "Haddad Mansour Saleh Nasser Hamdan Khalil Darwish Ibrahim Rahman Aziz Hakimi Benali Bensaid El_Amrani Bouzid Ziani Belhadj Al-Dawsari Al-Shahrani Al-Faraj Al-Ghannam Al-Owais Hosseini Rezaei Ahmadi Karimi Mohammadi Taremi Jafari Al-Ali Al-Hassan Al-Rawi"),
 "ja": ("Haruto Yuto Sota Yuki Takumi Kaito Ren Daiki Kenta Shota Ryo Kazuki Takuma Sho Hiroki Yuya Koji Ritsu Kaoru Wataru Ayase Junya Daichi Hidemasa",
        "Sato Suzuki Takahashi Tanaka Watanabe Ito Yamamoto Nakamura Kobayashi Kato Yoshida Yamada Sasaki Yamaguchi Matsumoto Inoue Kimura Hayashi Shimizu Yamazaki Mori Abe Ikeda Hashimoto Ishikawa Ogawa Okada Maeda Fujita Endo"),
 "ko": ("Min-jun Seo-jun Ji-ho Do-yun Ha-jun Jun-woo Hyun-woo Sung-min Tae-hee Jae-sung Wei Lei Jun Hao Chen-yu Minh Duc Tuan Anh Somchai Kittipong Thanawat Chanathip",
        "Kim Lee Park Choi Jung Kang Cho Yoon Jang Lim Han Oh Seo Shin Kwon Hwang Wang Li Zhang Liu Chen Yang Zhao Huang Zhou Wu Nguyen Tran Le Pham Hoang Phan Vu Dang Srisuk Chaiyaphum"),
 "gr": ("Giorgos Dimitris Kostas Nikos Giannis Christos Panagiotis Vasilis Thanasis Michalis Stelios Petros Andreas Sotiris Lefteris Fotis Manolis Tasos",
        "Papadopoulos Papadakis Georgiou Nikolaidis Konstantinou Ioannou Christodoulou Pappas Vlachos Karagiannis Oikonomou Alexiou Makris Antoniou Dimitriou Athanasiou Panagiotou Theodorou Stavrou Kyriakou"),
 "slav": ("Luka Ivan Marko Nikola Stefan Filip Petar Josip Mateo Dominik Ante Jakub Tomáš Lukáš Martin Kamil Piotr Krzysztof Mateusz Dmitri Sergei Andrei Alexei Mykola Oleksandr Bogdan Vlad Andrei Eldin Ermal Lorik Arbër Giorgi Levan Henrikh",
        "Horvat Kovačević Babić Marić Jurić Novak Petrović Jovanović Nikolić Ilić Đorđević Pavlović Popović Kowalski Nowak Wiśniewski Wójcik Lewandowski Zieliński Kamiński Dvořák Novotný Svoboda Ivanov Petrov Smirnov Kuznetsov Popescu Ionescu Stan Shevchenko Kovalenko Bondarenko Krasniqi Berisha Hoxha Kvaratskhelia Mamardashvili Nagy Szabó Tóth Horváth"),
 "nordic": ("Erik Lars Anders Johan Magnus Oskar Emil Mikkel Rasmus Kasper Mathias Jonas Kristoffer Sander Henrik Andreas Jesper Viktor Aron Gylfi Teemu Eetu Joonas Ole Martin Niklas",
        "Hansen Johansen Olsen Larsen Andersen Pedersen Nielsen Kristiansen Jensen Karlsson Andersson Johansson Nilsson Eriksson Larsson Olsson Persson Svensson Gustafsson Lindqvist Berg Haugen Bakke Sigurdsson Gudmundsson Virtanen Korhonen Mäkinen Nieminen"),
 "afr_fr": ("Moussa Ibrahima Mamadou Cheikh Ousmane Abdoulaye Boubacar Amadou Lamine Pape Idrissa Sadio Seydou Youssouf Bakary Franck Serge Wilfried Yves Jean Christian Arnaud Ismaël Hamari Karim",
        "Diallo Traoré Diop Ndiaye Sow Camara Koné Touré Cissé Kouyaté Sissoko Fofana Keita Bamba Coulibaly Konaté Diakité Sangaré Mendy Sarr Gueye Faye Kouassi Zaha Aboubakar Mbemba Kabongo Ilunga"),
 "afr_en": ("Samuel Joseph Emmanuel Victor Kelechi Chidi Musa Ademola Wilfred Tariq Kwame Kofi Yaw Thomas Daniel Michael Peter Godfrey Brian Teboho Percy Themba Sipho Kudakwashe Patson",
        "Okafor Okonkwo Adeyemi Babatunde Osimhen Iwobi Ndidi Lookman Mensah Boateng Asamoah Owusu Ayew Partey Kudus Otieno Wanyama Mbatha Zungu Khumalo Dlamini Banda Phiri Daka Musona Moyo"),
}


def pool(key):
    first, last = POOLS.get(key, POOLS["en"])
    return [x.replace("_", " ") for x in first.split(" ")], [x.replace("_", " ") for x in last.split(" ")]
