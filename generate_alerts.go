package main

import (
	"context"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/hamba/avro"
	"github.com/hamba/avro/ocf"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
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

	// Load schemas in a given folder
	schemaCandidate, err := avro.ParseFiles("schema/candidate.avsc")
	schemaCutout, err := avro.ParseFiles("schema/cutout.avsc")
	schemaAlert, err := avro.ParseFiles("schema/alert.avsc")
	alertCandidate := strings.Replace(schemaAlert.String(), "\"atlas.candidate\"", schemaCandidate.String(), 1)
	schema := strings.Replace(alertCandidate, "\"atlas.cutout\"", schemaCutout.String(), 1)

	// Open data directory
	outputDir := configuration.OutputDirectory
	// Get initial time
	start := time.Now()
	// Open data directory
	directory := os.Args[1]

	// Topic name
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

	schemaVersion := "0.1" // schema.Prop("version")

	// For each info file
	for _, infoFile := range infoFiles {

		baseName := filepath.Base(infoFile)
		name := baseName[:len(baseName)-len(filepath.Ext(baseName))]
		atlasRecord, err := generateAlert(name, directory, schemaVersion, tel)

		err = saveAvroFile(directory+"/"+outputDir+"/"+atlasRecord.Candid+".avro", schema, atlasRecord)
		if err != nil {
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

func generateAlert(baseName string, directory string, schemaVersion string, tel string) (*AtlasRecord, error) {
	// Read the alert information
	content, err := ioutil.ReadFile(directory + "/" + baseName + ".info")
	if err != nil {
		return nil, err
	}

	// Put the contents in an array
	contents := strings.Fields(string(content))

	alertData := []interface{}{schemaVersion, tel}
	// Put the contents of the file in the data of the alert
	for _, element := range contents {
		alertData = append(alertData, element)
	}
	// Generate cutouts
	cutouts := createCutouts(directory, baseName)
	// and append them
	alertData = append(alertData, cutouts["science"], cutouts["difference"], cutouts["template"])

	// Instantiate struct
	atlasRecord, err := createRecord(alertData)
	if err != nil {
		ErrorLogger.Println(err)
		return nil, err
	}
	return atlasRecord, nil
}

func saveAvroFile(path string, schema string, atlasRecord *AtlasRecord) error {
	// Open file to write to
	f, err := os.Create(path)
	if err != nil {
		ErrorLogger.Println(err)
		return err
	}

	enc, err := ocf.NewEncoder(schema, f)
	if err != nil {
		ErrorLogger.Println(err)
		return err
	}
	err = enc.Encode(atlasRecord)
	if err != nil {
		ErrorLogger.Println(err)
		return err
	}

	if err := enc.Flush(); err != nil {
		ErrorLogger.Println(err)
		return err
	}

	return nil
}

func loadAvroFile(infoFile string) (*AtlasRecord, error) {
	f, err := os.Open(infoFile)
	if err != nil {
		ErrorLogger.Println(err)
		return nil, err
	}

	dec, err := ocf.NewDecoder(f)
	if err != nil {
		ErrorLogger.Println(err)
		return nil, err
	}

	record := new(AtlasRecord)
	for dec.HasNext() {
		err = dec.Decode(&record)
		if err != nil {
			ErrorLogger.Println(err)
			return nil, err
		}

		break
	}
	return record, nil
}
