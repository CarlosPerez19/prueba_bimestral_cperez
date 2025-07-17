import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class Tarea {
  String id;
  String titulo;
  bool completada;
  String? fotoUrl;
  DateTime hora;
  bool compartida;

  Tarea({
    required this.id,
    required this.titulo,
    this.completada = false,
    this.fotoUrl,
    required this.hora,
    this.compartida = false,
  });

  factory Tarea.fromMap(Map<String, dynamic> map) {
    return Tarea(
      id: map['id'].toString(),
      titulo: map['titulo'] ?? '',
      completada: map['completada'] ?? false,
      fotoUrl: map['foto_url'],
      hora: DateTime.parse(map['hora']),
      compartida: map['compartida'] ?? false,
    );
  }
}

class TareasPage extends StatefulWidget {
  @override
  _TareasPageState createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final supabase = Supabase.instance.client;
  List<Tarea> tareasPropias = [];
  List<Tarea> tareasCompartidas = [];

  final _tituloController = TextEditingController();
  bool _pendiente = true;
  bool _esCompartida = false;
  File? _imagen;

  @override
  void initState() {
    super.initState();
    _cargarTareas();
  }

  Future<void> _cargarTareas() async {
    final usuarioId = supabase.auth.currentUser?.id;
    try {
      final data = await supabase
          .from('tareas')
          .select()
          .order('hora', ascending: false);

      setState(() {
        tareasPropias = (data as List<dynamic>)
            .where((t) => t['usuario_id'] == usuarioId && !(t['compartida'] ?? false))
            .map<Tarea>((t) => Tarea.fromMap(t as Map<String, dynamic>))
            .toList();
        tareasCompartidas = (data as List<dynamic>)
            .where((t) => t['compartida'] == true)
            .map<Tarea>((t) => Tarea.fromMap(t as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {}
  }

  Future<String?> _subirImagen(File imagen) async {
    final usuarioId = supabase.auth.currentUser?.id;
    final nombreArchivo = '${usuarioId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      final storageResponse = await supabase.storage
          .from('tareas')
          .upload(nombreArchivo, imagen);
      final url = supabase.storage.from('tareas').getPublicUrl(nombreArchivo);
      return url;
    } catch (e) {
      return null;
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imagen = File(pickedFile.path);
      });
    }
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imagen = File(pickedFile.path);
      });
    }
  }

  Future<void> _agregarTarea(bool pendiente, bool esCompartida, File? imagen) async {
    if (_tituloController.text.isEmpty) return;
    final usuarioId = supabase.auth.currentUser?.id;
    String? fotoUrl;
    if (imagen != null) {
      fotoUrl = await _subirImagen(imagen);
    }
    final now = DateTime.now();
    try {
      await supabase.from('tareas').insert({
        'usuario_id': usuarioId,
        'titulo': _tituloController.text,
        'completada': !pendiente ? true : false,
        'foto_url': fotoUrl,
        'hora': now.toIso8601String(),
        'compartida': esCompartida,
      });
      _tituloController.clear();
      _imagen = null;
      _pendiente = true;
      _esCompartida = false;
      await _cargarTareas();
      Navigator.of(context).pop();
    } catch (e) {}
  }

  Future<void> _marcarCompletada(Tarea tarea) async {
    try {
      await supabase
          .from('tareas')
          .update({'completada': true})
          .eq('id', tarea.id);
      await _cargarTareas();
    } catch (e) {}
  }

  void _mostrarFormularioTarea() {
    bool pendiente = true;
    bool esCompartida = false;
    File? imagen;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text('Nueva tarea', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    SizedBox(height: 16),
                    TextField(
                      controller: _tituloController,
                      decoration: InputDecoration(
                        labelText: 'Título de la tarea',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Estado:'),
                        Switch(
                          value: pendiente,
                          onChanged: (val) {
                            setModalState(() {
                              pendiente = val;
                            });
                          },
                          activeColor: Colors.blue,
                          inactiveThumbColor: Colors.green,
                        ),
                        Text(pendiente ? 'Pendiente' : 'Completada'),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Compartida:'),
                        Switch(
                          value: esCompartida,
                          onChanged: (val) {
                            setModalState(() {
                              esCompartida = val;
                            });
                          },
                          activeColor: Colors.orange,
                          inactiveThumbColor: Colors.grey,
                        ),
                        Text(esCompartida ? 'Sí' : 'No'),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await _seleccionarImagen();
                            setModalState(() {
                              imagen = _imagen;
                            });
                          },
                          child: Text('Seleccionar foto'),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            await _tomarFoto();
                            setModalState(() {
                              imagen = _imagen;
                            });
                          },
                          child: Text('Tomar foto'),
                        ),
                        if (imagen != null && imagen is File)
                          Container(
                            width: 50,
                            height: 50,
                            margin: EdgeInsets.only(left: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(imagen as File, fit: BoxFit.cover),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _agregarTarea(pendiente, esCompartida, imagen);
                        },
                        child: Text('Agregar tarea'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Tareas'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Divider(),
              Text('Tus tareas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ...tareasPropias.map((tarea) => Card(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: tarea.fotoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(tarea.fotoUrl!, width: 40, height: 40, fit: BoxFit.cover),
                            )
                          : Icon(Icons.task),
                      title: Text(tarea.titulo),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estado: ${tarea.completada ? "Completada" : "Pendiente"}'),
                          Text('Fecha: ${tarea.hora.toLocal().toString().split(' ')[0]}'),
                        ],
                      ),
                      trailing: !tarea.completada
                          ? IconButton(
                              icon: Icon(Icons.check),
                              onPressed: () => _marcarCompletada(tarea),
                            )
                          : Icon(Icons.check_circle, color: Colors.green),
                    ),
                  )),
              Divider(),
              Text('Tareas compartidas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ...tareasCompartidas.map((tarea) => Card(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: tarea.fotoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(tarea.fotoUrl!, width: 40, height: 40, fit: BoxFit.cover),
                            )
                          : Icon(Icons.task),
                      title: Text(tarea.titulo),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estado: ${tarea.completada ? "Completada" : "Pendiente"}'),
                          Text('Fecha: ${tarea.hora.toLocal().toString().split(' ')[0]}'),
                        ],
                      ),
                      trailing: !tarea.completada
                          ? IconButton(
                              icon: Icon(Icons.check),
                              onPressed: () => _marcarCompletada(tarea),
                            )
                          : Icon(Icons.check_circle, color: Colors.green),
                    ),
                  )),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormularioTarea,
        icon: Icon(Icons.add),
        label: Text('Nueva tarea'),
      ),
    );
  }
}