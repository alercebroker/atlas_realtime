package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"gopkg.in/avro.v0"
)

// Global map, stamp type to extension name
var info_fields = [...]string{"RA", "Dec", "Mag", "Dmag", "X", "Y", "Major",
	"Minor", "Phi", "Det", "ChiN", "Pvr", "Ptr", "Pmv", "Pkn", "Pno", "Pbn",
	"Pcr", "Pxt", "Psc", "Dup", "WPflx", "Dflx", "Candid", "ObjectID", "Mjd", "Filter"}

func Lastmodified(millise int64) time.Time {
	return time.Unix(0, millise*int64(time.Second))
}

func main() {
	// Load the configuration file
	configuration, err := loadConfiguration("config/config.json") // replace by relative path
	if err != nil {
		fmt.Println(err)
	}
	// Parse the schema file
	schema, err := avro.ParseSchemaFile(configuration.SchemaFile)
	if err != nil {
		fmt.Println(err)
	}
	// Open data directory
	output_dir := configuration.OutputDirectory
	// Get initial time
	start := time.Now()
	// Open data directory
	directory := os.Args[1]

	res1 := strings.Split(directory, "_")
	telnight := res1[len(res1)-1]
	//tel := telnight[:3]
	night, _ := strconv.ParseInt(telnight[3:], 10, 64)
	//topic := "atlas_" + night // + "_" +tel
	topic := Lastmodified((night - 40587) * 86400)
	topico := topic.Format("20060102")

	// Extension of files that contain the alert information
	info_extension := ".info"
	// Look for all the info files
	info_files, err := filepath.Glob(directory + "/*" + info_extension)
	if err != nil {
		fmt.Println(err)
	}
	// For each info file
	for _, info_file := range info_files {
		// Read the alert information
		content, _ := ioutil.ReadFile(info_file)
		// Put the contents in an array
		contents := strings.Fields(string(content))
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
		alert_data = append(alert_data, cutouts["science"],
			cutouts["difference"])
		// Open file to write to
		f, err := os.Create(directory + "/" + output_dir + "/" + candid + ".avro")
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
			fmt.Println(err)
		}
		// Create a fileWriter
		fileWriter, err := avro.NewDataFileWriter(f, schema, datumWriter)
		if err != nil {
			fmt.Println(err)
		}
		// fileWriter needs an argument
		err = fileWriter.Write(atlas_record)
		if err != nil {
			fmt.Println(err)
		}

		err = fileWriter.Flush()
		if err != nil {
			fmt.Println(err)
			return
		}
		// Close the file
		fileWriter.Close()

		if err := os.Remove(info_file); err != nil {
			panic(err)
		}
		//send avro alert to kafka
		//    produce(output_dir + "/" + candid + ".avro")
	}

	files, err := filepath.Glob(directory + "/*.fits")
	if err != nil {
		panic(err)
	}
	for _, f := range files {
		if err := os.Remove(f); err != nil {
			panic(err)
		}
	}
	produce(directory+"/"+output_dir, topico)
	elapsed := time.Since(start)
	fmt.Printf("Processing took %s\n", elapsed)
}
