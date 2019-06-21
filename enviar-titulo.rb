require 'savon'
require 'zip'
require 'batch_factory'

SEP_WSDL     ='https://metqa.siged.sep.gob.mx/met-ws/services/TitulosElectronicos.wsdl'
SEP_USER     ='TU-USUARIO'
SEP_PASSWORD ='TU-PASSWORD'

if ARGV.length != 1
  puts "Necesitas proporcionar el archivo XML como parametro"
  exit
end

xml_file = ARGV[0] 


client = Savon.client(wsdl: SEP_WSDL)
autenticacion = {usuario: SEP_USER, password:  SEP_PASSWORD}

# Enviar título
puts "-----------------------------------------------"
puts "Enviando título #{xml_file}..."
xml_encoded64 = Base64.encode64(File.read(xml_file))

client_call = client.call(:carga_titulo_electronico, message: {autenticacion: autenticacion, nombreArchivo: xml_file, archivoBase64: xml_encoded64 })
response = client_call.body[:carga_titulo_electronico_response]

lote = response[:numero_lote]
puts "XML enviado"
puts "Lote: #{lote}"
puts response[:mensaje]


# Consultar estado del proceso 
lote_resultado = -1

while lote_resultado != 1
  puts "-----------------------------------------------"
  puts "Consultando el proceso..."

  client_call = client.call(:consulta_proceso_titulo_electronico, message: {autenticacion: autenticacion, numeroLote: lote})
  response = client_call.body[:consulta_proceso_titulo_electronico_response]
  lote_resultado = response[:estatus_lote].to_i      
  
  if lote_resultado == 1
    puts "Lote procesado con exito"
  end
  
  puts response[:mensaje]
end
    
  
# Descargar resultados
puts "-----------------------------------------------"
puts "Descargando resultados del proceso..."

res = client.call(:descarga_titulo_electronico, message: {autenticacion: autenticacion, numeroLote: lote})
response = res.body[:descarga_titulo_electronico_response]

decoded64 = Base64.decode64(response[:titulos_base64])

zip_file = "response-#{xml_file}.zip" 

File.open(zip_file, 'w+') { |file| file.write(decoded64.force_encoding("UTF-8")) }

xls_file = ''
Zip::File.open(zip_file) do |zip_file|
  zip_file.each do |entry|
    puts "Descomprimiento #{entry.name}"
    xls_file = entry.name
    entry.extract(xls_file)
  end
end

hash_worksheet = BatchFactory.from_file xls_file


puts "-----------------------------------------------"
if hash_worksheet[0]['ESTATUS'] == "1"
  puts "XML procesado exitosamente"
else
  puts "XML con errores"
end

puts "Mensaje: #{hash_worksheet[0]['DESCRIPCION']}"

