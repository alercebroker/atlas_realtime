package main

import (
  "bytes"
  "fmt"
  "gopkg.in/avro.v0"
  "io/ioutil"
  "log"
  "os"
  "path/filepath"
  "strings"
  "time"
)

// Global map, stamp type to extension name
var info_fields = [...]string{"RA", "Dec", "Mag", "Dmag", "X", "Y", "Major",
"Minor", "Phi", "Det", "ChiN", "Pvr", "Ptr", "Pmv", "Pkn", "Pno", "Pbn",
"Pcr", "Pxt", "Psc", "Dup", "WPflx", "Dflx", "Candid", "ObjectID", "Mjd"}

// Open and return file
func openFile(fileName string) *os.File {
  // Open file
  file, err := os.Open(fileName)
  if err != nil {
    log.Fatal(err)
  }
  return file
}

func main() {
  // Load the configuration file
  configuration, err := loadConfiguration("/home/daniela/atlas-avro/config/config.json") // replace by relative path
  if err != nil {
    fmt.Println(err)
  }
  // Parse the schema file
  schema, err := avro.ParseSchemaFile(configuration.SchemaFile)
  if err != nil {
    log.Fatal(err)
  }
  // Get initial time
  start := time.Now()
  // Open data directory
  directory := os.Args[1]
  // Extension of files that contain the alert information
  info_extension := ".info"
  // Look for all the info files
  info_files, err := filepath.Glob(directory + "/*" + info_extension)
  fmt.Println(info_files)
  if err != nil {
    log.Fatal(err)
  }
  // For each info file
  for _, info_file := range info_files {
    // Read the alert information
    content, _ := ioutil.ReadFile(info_file)
    // Put the contents in an array
    contents := strings.Fields(string(content))
    /*
    // Beginning of test code
    for _, field := range info_fields {

    }
    */
    // Begin by adding the schema version
    schema_version := "0.1"
    alert_data := []interface{}{schema_version}
    // Put the contents of the file in the data of the alert
    for _, element := range contents {
      alert_data = append(alert_data, element)
    }
    // Get the file's base name (file name including the extension)
    base_name := filepath.Base(info_file)
    // Leave just the name (candid)
    candid := strings.TrimSuffix(base_name, info_extension)
    // Generate cutouts
    cutouts := createCutouts(directory, candid)
    // and append them
    alert_data = append(alert_data, cutouts["template"],
      cutouts["science"], cutouts["difference"])
    // Open file to write to
    f, err := os.Create(candid + ".avro")
    if err != nil {
      fmt.Println(err)
      return
    }
    // Create buffer to store data
    var buf bytes.Buffer
    encoder := avro.NewBinaryEncoder(&buf)
    // Create DatumWriter and set schema
    datumWriter := avro.NewSpecificDatumWriter()
    datumWriter.SetSchema(schema)
    // Instantiate struct
    atlas_record := createRecord(alert_data)
    // Write the data to the buffer through datumWriter
    err = datumWriter.Write(atlas_record, encoder)
    if err != nil {
      log.Fatal(err)
    }
    // Create a fileWriter
    fileWriter, err := avro.NewDataFileWriter(f, schema, datumWriter)
    if err != nil {
      log.Fatal(err)
    }
    // fileWriter needs an argument
    err = fileWriter.Write(atlas_record)
    err = fileWriter.Flush()
    if err != nil {
      fmt.Println(err)
      return
    }
    // Close the file
    fileWriter.Close()
  }
  elapsed := time.Since(start)
  log.Printf("Processing took %s", elapsed)
}
