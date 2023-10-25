#!/usr/local/bin/dart

import 'dart:convert';
import 'dart:io';

main(List<String> arguments) async {
  // String str = "{alaostia,plural,=0{Sin opciones}=1{1 Opción}other{{count} {ejemplo,Opciones}}";
  //
  // List<int> texts = countersAdvancedPlural(str);
  // print(texts); // Output: [Sin opciones, 1 Opción, {count} Opciones]
  // print(params(str));
  // print(counterPluralName(str));
  //
  // return;

  // print(process(
  //   "{alaostia,plural,=0{Sin opciones}=1{1 Opción}other{{count} {ejemplo,Opciones}}",
  //   {'count': 1, 'alaostia': 1},
  // ));
  //
  // print(process(
  //   "{alaostia,plural,=0{Sin opciones}=1{1 Opción}other{{count} {ejemplo,Opciones}}",
  //   {'count': 1, 'alaostia': 0},
  // ));
  //
  // print(processAdvancedPlural(
  //   "{alaostia,plural,=0{Sin opciones}=1{1 Opción}other{{count} {ejemplo,Opciones}}",
  //   {'count': 'ojo', 'alaostia': 4},
  // ));
  //
  // return;

  // String source = '{'
  //     // '"a": "{alaostia,plural,=0{Sin opciones}=1{1 Opción}other{{count} {ejemplo,Opciones}}",'
  //     // '"b": "planta | plantas",'
  //     // '"c": "hola",'
  //     // '"d": "{pax_count_pax,plural, =1{Pax}other{Pax}}",'
  //     // '"e": "{room,plural, =0{Sin habitación}=1{Habitación}other{Habitaciones}}",'
  //     '"f": "{count,plural,=0{a ver}=1{1 veremos}other{{count} {veamos}}"'
  //     '}';

  var replacer = '##';
  if (arguments.length < 3) {
    print('Usage: trl en es intl_en.arb.json');
    return;
  }
  var langIn = arguments[0];
  var langsOut = arguments[1];
  var fileTemplate = arguments[2];

  for (String langOut in langsOut.split(',')) {
    print('starting  $langOut');
    print('---------------------------');

    File inFile = new File(fileTemplate.replaceAll(replacer, langIn));
    String inSource = inFile.existsSync() ? inFile.readAsLinesSync().join('\n') : '{}';
    Map<String, dynamic> inMap = jsonDecode(inSource);

    File outFile = new File(fileTemplate.replaceAll(replacer, langOut).replaceAll(langIn, langOut));
    String outSource = outFile.existsSync() ? outFile.readAsLinesSync().join('\n') : '{}';
    Map<String, dynamic> outMap = jsonDecode(outSource);

    for (var key in inMap.keys) {
      if (outMap.containsKey(key) || key == 'lang' || key == '@@locale') continue;

      String src = inMap[key];
      print('translating: $src');

      var res = src;
      var tr = '$res';
      if (src.contains(' | ')) {
        tr = await translate(res, langIn, langOut);
      } else //advanced plural {...,plural, ...}
      if (src.startsWith('{') && src.endsWith('}') && src.contains(',plural,')) {
        var count = counters(src);
        var pluralP = pluralParam(src);
        var par = params(src);
        par.remove(pluralP);
        Map<String, dynamic> mapParamsValue = par.asMap().map((key, value) => MapEntry(value, '0x$value'));

        //"{alaostia,plural,
        // =0{Sin opciones}=1{1 Opción}other{{count} Opciones}
        // }"
        String s = '';
        for (var i in count) {
          mapParamsValue[pluralP!] = i;
          String sp = processAdvancedPlural(src, mapParamsValue);
          String trr = await translate(sp, langIn, langOut);

          for (var key in mapParamsValue.keys) {
            trr = trr.replaceAll('${mapParamsValue[key]!}', '{$key}');
          }

          s += (i == -1 ? 'other' : '=$i') + '{$trr}';
        }
        tr = '{$pluralP,plural,${s}}';
      } else {
        tr = await translate(res, langIn, langOut);
      }

      print('translated: $tr');
      print('---------------------------');
      outMap[key] = tr;
      JsonEncoder encoder = JsonEncoder.withIndent('  '); // 2 espacios de indentación
      outSource = encoder.convert(outMap);
      outFile.writeAsStringSync(outSource);
    }

    print('-----------------------------------');
    print('done $langOut');
  }
  print('done all');
  exit(0);
}

Future<String> translate(String text, String from, String to) async {
  // Replace the URL with the endpoint you want to fetch data from
  String url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$from&tl=$to&dt=t&q=${Uri.encodeComponent(text)}';
  //GET
  // 	https://translate.googleapis.com/translate_a/single?client=gtx&sl=es&tl=de&dt=t&q=TGE-Hotelero

  // Create a HttpClient
  HttpClient httpClient = HttpClient();

  // Perform the GET request
  var response = await httpClient.getUrl(Uri.parse(url)).then((HttpClientRequest request) {
    // Send the request and wait for the response
    return request.close();
  }).catchError((error) {
    // Handle any errors that occurred during the request
    print('Error: $error');
  }); //.then((HttpClientResponse response)
  {
    if (response.statusCode == HttpStatus.ok) {
      // If the request is successful (status code 200), read the response data
      var responseBody = await response.transform(utf8.decoder).join();
      // .listen((String responseBody) {
      // Here, we assume the response body is in UTF-8 encoded format
      // You may need to handle other encodings depending on the server's response

      // Do something with the fetched data
      // print(responseBody);
      var r = jsonDecode(responseBody);
      String? tr1 = () {
        try {
          return r[0]?[1]?[0];
        } catch (e) {
          return null;
        }
      }.call();
      String tr0 = r[0][0][0];

      return tr0 + (tr1 != null ? ' ${tr1}' : '');
      // });
    } else {
      // If the request is not successful, print the error status code and reason
      print('Request failed with status: ${response.statusCode}.');
      return text;
    }
  }
}

String? pluralParam(String str) => str.startsWith('{') && str.endsWith('}') && str.contains(',plural,')
    ? str.split(',plural,')[0].substring(1)
    : str.contains(' | ')
        ? 'count'
        : null;

///obtener los parametros en un string, {count}
///for generation
List<String> params(String str) {
  List<String> res = str.startsWith('{') && str.endsWith('}') && str.contains(',plural,') ? [pluralParam(str)!] : [];
  // RegExp regex = RegExp(r"\{(\w+),(\w+),(.*?)\}");
  RegExp regex = RegExp(r"\{(\w+)\}");
  Iterable<Match> matches = regex.allMatches(str);
  for (int i = 0; i < matches.length; i++) {
    if (!res.contains(matches.toList()[i].group(1) ?? '')) {
      res.add(matches.toList()[i].group(1) ?? '');
    }
  }
  return res;
}

List<int> counters(String str) {
  List<int> res = [];
  if (str.contains(' | ')) {
    res = countersSimplePlural(str);
  } else //advanced plural {...,plural, ...}
  if (str.startsWith('{') && str.endsWith('}') && str.contains(',plural,')) {
    res = countersAdvancedPlural(str);
  } else {
    res = [];
  }

  return res;
}

//get advanced plural counters
List<int> countersAdvancedPlural(String str) {
  List<int> res = [];
  RegExp exp = RegExp(r"=(\d+)");

  Iterable<Match> matches = exp.allMatches(str);

  for (Match match in matches) {
    res.add(int.parse(match.group(1)!));
  }
  if (str.contains('}other{')) {
    res.add(-1);
  }
  return res;
}

List<int> countersSimplePlural(String str) => [1, -1];

String process(String str, [Map<String, dynamic>? params]) {
  params ??= {};
  params['count'] = params['count'] ?? 1;

  String res = 'str';
  //detecting plurals
  //simple plural separated by ' | '
  if (str.contains(' | ')) {
    res = processSimplePlural(str, params['count']);
  } else //advanced plural {...,plural, ...}
  if (str.startsWith('{') && str.endsWith('}') && str.contains(',plural,')) {
    res = processAdvancedPlural(str, params);
  } else {
    res = str;
  }

  for (var key in params.keys) {
    res = res.replaceAll('{\$key}', params[key]?.toString() ?? '');
  }

  return res;
}

String processSimplePlural(String str, int count) => str.split('|')[count == 1 ? 0 : 1];

String processAdvancedPlural(String str, Map<String, dynamic> params) {
  //ex: "{room,plural, =1{1 room {gratuityExtra} free extra}other{{room} rooms {gratuityExtra} free extra}}"

  List<String> all = str.split(',');
  String paramName = all[0].substring(1);
  int count = params[paramName] ?? 1;

  var text = str.substring(str.indexOf(',plural,') + 8, str.length - 1);

  if (!text.contains('other{')) throw Exception('Error should contains other clause');

  var otherText = text.substring(text.indexOf('other{') + 6, text.length - 1);
  var map = {
    -1: otherText,
  };

  // Paso 1: Crear una expresión regular para encontrar todos los '=X{'.
  RegExp exp = RegExp(r"=(\d+)\{");
  // Paso 2: Encontrar todas las coincidencias en la cadena.

  var str1 = str.substring(0, str.indexOf('other{'));

  List<RegExpMatch> matches = exp.allMatches(str1).toList();

  // Paso 3 y 4: Procesar cada coincidencia para extraer la clave y el valor.
  for (int i = 0; i < matches.length; i++) {
    RegExpMatch match = matches[i];
    // Extraer la clave 'X'.
    int key = int.parse(match.group(1) ?? '1');
    // Buscar la posición de inicio y final del valor.
    int valueStart = match.end;
    int valueEnd;
    if (i + 1 < matches.length) {
      valueEnd = matches[i + 1].start - 1;
    } else {
      valueEnd = str1.length - 1;
    }
    // Extraer el valor.
    String value = str1.substring(valueStart, valueEnd);
    map[key] = value;
  }

  String res = '';
  if (map.keys.contains(count)) {
    res = map[count] ?? 'WTF';
  } else {
    res = map[-1] ?? 'WTF';
  }

  for (var key in params.keys) {
    res = res.replaceAll('{$key}', params[key]?.toString() ?? '');
  }
  return res;
}

String counterPluralName(String str) => str.contains(',plural,') ? str.split(',plural,')[0].substring(1) : 'count';
