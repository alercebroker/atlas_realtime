package main

import (
	"context"
	"log"
	"math"
	"os"
	"strconv"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

const (
	RADIUS = 1.5
	// Values from WGS 84
	a     = 6378137.000000000000 // Semi-major axis of Earth
	e     = 0.081819190842600    // eccentricity
	angle = math.Pi / 180
)

// Structs definitions

type Cutout struct {
	FileName  string `avro:"fileName"`
	StampData []byte `avro:"stampData"` // bytes
}

type Candidate struct {
	Candid    string  `avro:"candid"`
	RA        float64 `avro:"RA"`
	Dec       float64 `avro:"Dec"`
	Mag       float32 `avro:"Mag"`
	Dmag      float32 `avro:"Dmag"`
	X         float32 `avro:"X"`
	Y         float32 `avro:"Y"`
	Major     float32 `avro:"Major"`
	Minor     float32 `avro:"Minor"`
	Phi       float64 `avro:"Phi"`
	Det       int32   `avro:"Det"`
	ChiN      float64 `avro:"ChiN"`
	Pvr       int32   `avro:"Pvr"`
	Ptr       int32   `avro:"Ptr"`
	Pmv       int32   `avro:"Pmv"`
	Pkn       int32   `avro:"Pkn"`
	Pno       int32   `avro:"Pno"`
	Pbn       int32   `avro:"Pbn"`
	Pcr       int32   `avro:"Pcr"`
	Pxt       int32   `avro:"Pxt"`
	Psc       int32   `avro:"Psc"`
	Dup       int32   `avro:"Dup"`
	WPflx     float32 `avro:"WPflx"`
	Dflx      float32 `avro:"Dflx"`
	Mjd       float64 `avro:"mjd"`
	Filter    string  `avro:"filter"`
	Pid       int64   `avro:"pid"`
	Isdiffpos string  `avro:"isdiffpos"`
	Flux      float32 `avro:"flux"`
	Dflux     float32 `avro:"Dflux"`
	Rb        float32 `avro:"rb"`
}

type AtlasRecord struct {
	Schemavsn        string     `avro:"schemavsn"`
	Publisher        string     `avro:"publisher"`
	Candidate        *Candidate `avro:"candidate"`
	Candid           string     `avro:"candid"`
	ObjectId         string     `avro:"objectId"`
	CutoutScience    *Cutout    `avro:"cutoutScience"`
	CutoutTemplate   *Cutout    `avro:"cutoutTemplate"`
	CutoutDifference *Cutout    `avro:"cutoutDifference"`
}

// Global map, stamp type to extension name
var getExtension = map[string]string{
	"science":    "_istamp.fits.gz",
	"difference": "_dstamp.fits.gz",
	"template":   "_rstamp.fits.gz",
}

func createCutouts(directory string, candid string) map[string]*Cutout {
	// Holder for cutouts
	cutouts := make(map[string]*Cutout)
	// Fill cutout map
	for kind := range getExtension {
		// Cutout name
		cutoutFileName := candid + getExtension[kind]
		// Read stamp data
		cutoutData, err := os.ReadFile(directory + "/" + cutoutFileName)
		if err != nil {
			ErrorLogger.Println(err)
			break
		}
		// Create cutout object
		pCutout := &Cutout{
			FileName:  cutoutFileName,
			StampData: cutoutData,
		}
		// Append cutout to array
		cutouts[kind] = pCutout
	}
	return cutouts
}

func createCandidate(data []interface{}) *Candidate {
	RA, _ := strconv.ParseFloat(data[0].(string), 64)
	Dec, _ := strconv.ParseFloat(data[1].(string), 64)
	Mag, _ := strconv.ParseFloat(data[2].(string), 32)
	Dmag, _ := strconv.ParseFloat(data[3].(string), 32)
	X, _ := strconv.ParseFloat(data[4].(string), 32)
	Y, _ := strconv.ParseFloat(data[5].(string), 32)
	Major, _ := strconv.ParseFloat(data[6].(string), 32)
	Minor, _ := strconv.ParseFloat(data[7].(string), 32)
	Phi, _ := strconv.ParseFloat(data[8].(string), 64)
	Det, _ := strconv.ParseInt(data[9].(string), 10, 32)
	ChiN, _ := strconv.ParseFloat(data[10].(string), 64)
	Pvr, _ := strconv.ParseInt(data[11].(string), 10, 32)
	Ptr, _ := strconv.ParseInt(data[12].(string), 10, 32)
	Pmv, _ := strconv.ParseInt(data[13].(string), 10, 32)
	Pkn, _ := strconv.ParseInt(data[14].(string), 10, 32)
	Pno, _ := strconv.ParseInt(data[15].(string), 10, 32)
	Pbn, _ := strconv.ParseInt(data[16].(string), 10, 32)
	Pcr, _ := strconv.ParseInt(data[17].(string), 10, 32)
	Pxt, _ := strconv.ParseInt(data[18].(string), 10, 32)
	Psc, _ := strconv.ParseInt(data[19].(string), 10, 32)
	Dup, _ := strconv.ParseInt(data[20].(string), 10, 32)
	WPflx, _ := strconv.ParseFloat(data[21].(string), 32)
	Dflx, _ := strconv.ParseFloat(data[22].(string), 32)
	Candid, _ := data[23].(string)
	Mjd, _ := strconv.ParseFloat(data[24].(string), 64)
	Filter, _ := data[25].(string)
	tel := Candid[:2]
	night := Candid[3:8]
	exp := Candid[9:13]
	Pid, _ := strconv.ParseInt(tel+night+exp, 10, 64)
	Isdiffpos := "t"
	if Det == 5 {
		Isdiffpos = "f"
	}
	Flux := math.Pow(10, -(math.Abs(Mag)-23.9)/2.5)
	if Mag < 0 {
		Flux = -Flux
	}
	Dflux := Dmag * Flux
	Rb := float32(0.0)
	candidate := &Candidate{
		Candid:    Candid,
		RA:        RA,
		Dec:       Dec,
		Mag:       float32(Mag),
		Dmag:      float32(Dmag),
		X:         float32(X),
		Y:         float32(Y),
		Major:     float32(Major),
		Minor:     float32(Minor),
		Phi:       Phi,
		Det:       int32(Det),
		ChiN:      ChiN,
		Pvr:       int32(Pvr),
		Ptr:       int32(Ptr),
		Pmv:       int32(Pmv),
		Pkn:       int32(Pkn),
		Pno:       int32(Pno),
		Pbn:       int32(Pbn),
		Pcr:       int32(Pcr),
		Pxt:       int32(Pxt),
		Psc:       int32(Psc),
		Dup:       int32(Dup),
		WPflx:     float32(WPflx),
		Dflx:      float32(Dflx),
		Mjd:       Mjd,
		Filter:    Filter,
		Pid:       Pid,
		Isdiffpos: Isdiffpos,
		Flux:      float32(Flux),
		Dflux:     float32(Dflux),
		Rb:        Rb,
	}
	return candidate
}

func createRecord(data []interface{}) (*AtlasRecord, error) {
	/*
	 * Candidate fields are: RA, Dec, Mag, Dmag, X, Y, Major, Minor,
	 * Phi, Det, ChiN, Pvr, Ptr, Pmv, Pkn, Pno, Pbn, Pxt, Pcr, Dup,
	 * WPflx, Dflx, Mjd, Filter
	 */
	// Float64 array to store candidate fields
	candidateData := []interface{}{data[2]} // RA
	// Put the contents of the file in the data of the alert
	for i, element := range data[3:29] { // does not include 28
		realCount := i + 3
		// Skip candid and objectID
		if realCount == 26 {
		} else {
			candidateData = append(candidateData, element)
		}
	}
	// Create candidate
	pCandidate := createCandidate(candidateData)
	// Non candidate fields
	Schemavsn := data[0].(string)
	tel := data[1].(string)
	Publisher := "ATLAS-" + tel
	Candidate := pCandidate
	Candid := data[25].(string)
	ObjectId, err := getOrCreateId(data[25].(string), pCandidate.RA, pCandidate.Dec)
	if err != nil {
		return nil, err
	}

	// data[26] is mjd,  data[27] is filter, those value goes in the candidate
	CutoutScience := data[29].(*Cutout)
	CutoutDifference := data[30].(*Cutout)
	CutoutTemplate := data[31].(*Cutout)
	// Create atlas record
	atlasRecord := &AtlasRecord{
		Schemavsn:        Schemavsn,
		Publisher:        Publisher,
		Candidate:        Candidate,
		Candid:           Candid,
		ObjectId:         ObjectId,
		CutoutScience:    CutoutScience,
		CutoutTemplate:   CutoutTemplate,
		CutoutDifference: CutoutDifference,
	}
	return atlasRecord, nil
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
