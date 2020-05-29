package main

import (
	"fmt"
	"gopkg.in/avro.v0"
	"log"
)

func verify(file string) {
	// Load the configuration file
	configuration, err := loadConfiguration("config/config.json") // replace by relative path
	if err != nil {
	  fmt.Println(err)
	}
	// Parse the schema file
	schema, err := avro.ParseSchemaFile(configuration.SchemaFile)
	if err != nil {
	  log.Fatal(err)
	}

    // Create DatumWriter and set schema
    datumReader := avro.NewSpecificDatumReader()
	datumReader.SetSchema(schema)

	// Provide a filename to read and a DatumReader to manage the reading itself
	fileReader, err := avro.NewDataFileReader(file, datumReader)
	if err != nil {
		// Should not actually happen
		panic(err)
	}

	// Create a new TestRecord to decode data into
	decodedRecord := new(AtlasRecord)

	b, err := fileReader.Next(decodedRecord)
	if err != nil || !b {
		panic(err)
	}

	fmt.Printf("Read a value: %s\n", decodedRecord.Candid)
}