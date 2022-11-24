package main

import (
	"bytes"
	"context"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"gopkg.in/avro.v0"
)

var client *mongo.Client
var configuration *Configuration
var (
	InfoLogger  *log.Logger
	ErrorLogger *log.Logger
)

func init() {
	var err error

	// Load the configuration file
	configuration, err = loadConfiguration("config/config.json") // replace by relative path
	if err != nil {
		log.Fatal(err)
	}

	// Logs config
	eFile, err := os.OpenFile(configuration.ErrFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0666)
	if err != nil {
		log.Fatal(err)
	}
	// Logs config
	lFile, err := os.OpenFile(configuration.LogFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0666)
	if err != nil {
		log.Fatal(err)
	}

	InfoLogger = log.New(lFile, "INFO: ", log.Ldate|log.Ltime|log.Lshortfile)
	ErrorLogger = log.New(eFile, "ERROR: ", log.Ldate|log.Ltime|log.Lshortfile)

	// Database config
	// Set client options
	clientOptions := options.Client().ApplyURI("mongodb://" + configuration.MongodbUser + ":" + configuration.MongodbPass + "@" + configuration.MongodbHost + ":" + configuration.MongodbPort + "/?authSource=staging")

	// Connect to MongoDB
	client, err = mongo.Connect(context.TODO(), clientOptions)

	if err != nil {
		ErrorLogger.Fatal("Invalid DB config:", err)
	}

	// Check the connection
	err = client.Ping(context.TODO(), nil)

	if err != nil {
		ErrorLogger.Fatal("DB unreachable:", err)
	}
}

func lastModified(sec int64) time.Time {
	return time.Unix(0, sec*int64(time.Second))
}

func main() {

	// Parse the schema file
	schema, err := avro.ParseSchemaFile(configuration.SchemaFile)
	if err != nil {
		ErrorLogger.Println(err)
	}
	// Open data directory
	outputDir := configuration.OutputDirectory
	// Get initial time
	start := time.Now()
	// Open data directory
	directory := os.Args[1]

	res1 := strings.Split(directory, "_")
	telNight := res1[len(res1)-1]
	tel := telNight[:3]
	night, _ := strconv.ParseInt(telNight[3:], 10, 64)
	topic := lastModified((night - 40586) * 86400)
	topics := "ATLAS_" + topic.Format("20060102") + "_" + tel

	// Extension of files that contain the alert information
	infoExtension := ".info"
	// Look for all the info files
	infoFiles, err := filepath.Glob(directory + "/*" + infoExtension)
	if err != nil {
		ErrorLogger.Println(err)
	}
	// For each info file
	for _, infoFile := range infoFiles {
		// Read the alert information
		content, err := ioutil.ReadFile(infoFile)
		if err != nil {
			ErrorLogger.Println(infoFile, err)
			continue
		}
		// Put the contents in an array
		contents := strings.Fields(string(content))
		// Begin by adding the schema version
		schemaVersion := "0.1"
		alertData := []interface{}{schemaVersion}
		// Put the contents of the file in the data of the alert
		for _, element := range contents {
			alertData = append(alertData, element)
		}
		// Get the file's base name (file name including the extension)
		baseName := filepath.Base(infoFile)
		// Leave just the name (candid)
		candid := strings.TrimSuffix(baseName, infoExtension)
		// Generate cutouts
		cutouts := createCutouts(directory, candid)
		// and append them
		alertData = append(alertData, cutouts["science"],
			cutouts["difference"])
		// Open file to write to
		f, err := os.Create(directory + "/" + outputDir + "/" + candid + ".avro")
		if err != nil {
			ErrorLogger.Println(err)
			return
		}
		// Create buffer to store data
		var buf bytes.Buffer
		encoder := avro.NewBinaryEncoder(&buf)
		// Create DatumWriter and set schema
		datumWriter := avro.NewSpecificDatumWriter()
		datumWriter.SetSchema(schema)
		// Instantiate struct
		atlasRecord, err := createRecord(alertData, tel)
		if err != nil {
			ErrorLogger.Println(err)
			continue
		}
		// Write the data to the buffer through datumWriter
		err = datumWriter.Write(atlasRecord, encoder)
		if err != nil {
			ErrorLogger.Println(err)
			continue
		}
		// Create a fileWriter
		fileWriter, err := avro.NewDataFileWriter(f, schema, datumWriter)
		if err != nil {
			ErrorLogger.Println(err)
			continue
		}
		// fileWriter needs an argument
		err = fileWriter.Write(atlasRecord)
		if err != nil {
			ErrorLogger.Println(err)
			continue
		}

		err = fileWriter.Flush()
		if err != nil {
			ErrorLogger.Println(err)
			continue
		}
		// Close the file
		err = fileWriter.Close()
		if err != nil {
			ErrorLogger.Println(err)
			continue
		}

		if err := os.Remove(infoFile); err != nil {
			ErrorLogger.Println(err)
			continue
		}
		// send avro alert to kafka
		//    produce(outputDir + "/" + candid + ".avro")
	}

	files, err := filepath.Glob(directory + "/*.fits")
	if err != nil {
		ErrorLogger.Println(err)
	}
	for _, f := range files {
		if err := os.Remove(f); err != nil {
			ErrorLogger.Println(err)
		}
	}
	err = produce(directory+"/"+outputDir, topics, configuration.KafkaServer1)
	if err != nil {
		ErrorLogger.Println(err)
	}
	err = produce(directory+"/"+outputDir, topics, configuration.KafkaServer2)
	if err != nil {
		ErrorLogger.Println(err)
	}

	err = os.RemoveAll(directory)
	if err != nil {
		ErrorLogger.Println(err)
	}

	// close a connection
	err = client.Disconnect(context.TODO())

	if err != nil {
		ErrorLogger.Println(err)
	}
	elapsed := time.Since(start)
	InfoLogger.Printf("Processing took %s %s\n", elapsed, topics)
}
