package main

import (
	"context"
	"go.mongodb.org/mongo-driver/bson"
	"io/ioutil"
	"log"
	"math"
	"os"
	"path/filepath"
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

func configLogs() (*log.Logger, *log.Logger) {
	var err error

	// Load the configuration file
	configuration, err = loadConfiguration("config/config.json") // replace by relative path
	if err != nil {
		log.Fatal(err)
	}

	// Logs config
	lFile, err := os.OpenFile(configuration.LogFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0666)
	if err != nil {
		log.Fatal(err)
	}

	iLogger := log.New(lFile, "INFO: ", log.Ldate|log.Ltime|log.Lshortfile)
	eLogger := log.New(lFile, "ERROR: ", log.Ldate|log.Ltime|log.Lshortfile)
	return iLogger, eLogger
}

func db() *mongo.Client {
	var err error
	// Database config
	// Set client options
	clientOptions := options.Client().ApplyURI("mongodb://" + configuration.MongodbUser + ":" + configuration.MongodbPass + "@" + configuration.MongodbHost + ":" + configuration.MongodbPort)

	// Connect to MongoDB
	client, err = mongo.Connect(context.TODO(), clientOptions)

	if err != nil {
		log.Fatal("Invalid MongoDB config:", err)
	}

	// Check the connection
	err = client.Ping(context.TODO(), nil)

	if err != nil {
		log.Fatal("MongoDB unreachable:", err)
	}
	return client
}

func lastModified(sec int64) time.Time {
	return time.Unix(0, sec*int64(time.Second))
}

func main() {

	InfoLogger, ErrorLogger = configLogs()
	client = db()

	// Load schemas in a given folder
	schemaCandidate, err := avro.ParseFiles("schema/candidate.avsc")
	if err != nil {
		ErrorLogger.Fatal("Invalid avro schema:", err)
	}
	schemaCutout, err := avro.ParseFiles("schema/cutout.avsc")
	if err != nil {
		ErrorLogger.Fatal("Invalid avro schema:", err)
	}
	schemaAlert, err := avro.ParseFiles("schema/alert.avsc")
	if err != nil {
		ErrorLogger.Fatal("Invalid avro schema:", err)
	}
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
	topics := "atlas"

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
		if err != nil {
			ErrorLogger.Println(err)
			continue
		}

		previousId, err := getOrCreateId(atlasRecord.ObjectId, atlasRecord.Candidate.RA, atlasRecord.Candidate.Dec)
		if err != nil {
			ErrorLogger.Println(err)
		} else {
			atlasRecord.ObjectId = previousId
		}

		err = saveAvroFile(directory+"/"+outputDir+"/"+atlasRecord.Candid+".avro", schema, atlasRecord)
		if err != nil {
			ErrorLogger.Println(err)
		}

	}

	err = produce(directory+"/"+outputDir, topics, configuration.KafkaServer, configuration.KafkaUser, configuration.KafkaPassword)
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
	if dec.HasNext() {
		err = dec.Decode(&record)
		if err != nil {
			ErrorLogger.Println(err)
			return nil, err
		}
	}
	return record, nil
}

func getOrCreateId(s string, ra float64, dec float64) (string, error) {
	// get a handle for the trainers collection in the test database
	collection := client.Database(configuration.Db).Collection(configuration.Col)

	// Find documents
	// Pass these options to the Find method
	findOptions := options.Find()
	findOptions.SetLimit(1)
	findOptions.SetProjection(bson.D{{Key: "_id", Value: 1}})

	// Passing bson.D{{}} as the filter matches all documents in the collection
	radius := RADIUS / 3600
	scaling := wgsScale(dec)
	meterRadius := radius * scaling
	lon, lat := ra-180.0, dec

	filter := bson.D{
		{
			Key: "loc",
			Value: bson.D{
				{
					Key: "$nearSphere",
					Value: bson.D{
						{
							Key: "$geometry",
							Value: bson.D{
								{
									Key:   "type",
									Value: "Point",
								},
								{
									Key:   "coordinates",
									Value: bson.A{lon, lat},
								},
							},
						},
						{
							Key:   "$maxDistance",
							Value: meterRadius,
						},
					},
				},
			},
		},
	}

	cur, err := collection.Find(context.TODO(), filter, findOptions)
	if err != nil {
		return s, err
	}

	// Finding multiple documents returns a cursor
	// Iterating through the cursor allows us to decode documents one at a time
	if cur.Next(context.TODO()) {

		// create a value into which the single document can be decoded
		elem := struct {
			ObjectId string `bson:"_id"`
		}{}
		err := cur.Decode(&elem)
		if err != nil {
			return s, err
		}

		return elem.ObjectId, nil
	}

	asht := bson.D{
		{
			Key: "_id", Value: s,
		},
		{
			Key: "loc", Value: bson.D{
				{
					Key: "type", Value: "Point",
				},
				{
					Key: "coordinates", Value: bson.A{lon, lat},
				},
			},
		},
	}

	_, err = collection.InsertOne(context.TODO(), asht)
	if err != nil {
		log.Fatal(err)
	}

	return s, nil
}

func wgsScale(lat float64) float64 {
	/*
		Get scaling to convert degrees to meters at a given geodetic latitude (declination)
		:param lat: geodetic latitude (declination)
		:return:
	*/
	// Compute radius of curvature along meridian (see https://en.wikipedia.org/wiki/Meridian_arc)
	rm := a * (1 - math.Pow(e, 2)) / math.Pow(1-math.Pow(e, 2)*math.Pow(math.Sin(lat*math.Pi/180), 2), 1.5)

	// Compute length of arc at this latitude (meters/degree)
	arc := rm * angle
	return arc
}
