package main

import (
  //"fmt"
  "io/ioutil"
  "strconv"
)

// Structs definitions

type Cutout struct {
  FileName string `avro:"fileName"`
  StampData []byte `avro:"stampData"` // bytes
}

type Candidate struct {
  Candid string `avro:"candid"`
  RA float64 `avro:"RA"`
  Dec float64 `avro:"Dec"`
  Mag float64 `avro:"Mag"`
  Dmag float64 `avro:"Dmag"`
  X float64 `avro:"X"`
  Y float64 `avro:"Y"`
  Major float64 `avro:"Major"`
  Minor float64 `avro:"Minor"`
  Phi float64 `avro:"Phi"`
  Det float64 `avro:"Det"`
  ChiN float64 `avro:"ChiN"`
  Pvr float64 `avro:"Pvr"`
  Ptr float64 `avro:"Ptr"`
  Pmv float64 `avro:"Pmv"`
  Pkn float64 `avro:"Pkn"`
  Pno float64 `avro:"Pno"`
  Pbn float64 `avro:"Pbn"`
  Pcr float64 `avro:"Pcr"`
  Pxt float64 `avro:"Pxt"`
  Psc float64 `avro:"Psc"`
  Dup float64 `avro:"Dup"`
  WPflx float64 `avro:"WPflx"`
  Dflx float64 `avro:"Dflx"`
  Mjd float64 `avro:"mjd"`
  Filter string `avro:"filter"`
}

type AtlasRecord struct {
  Schemavsn string `avro:"schemavsn"`
  Publisher string `avro:"publisher"`
  Candidate *Candidate `avro:"candidate"`
  Candid string `avro:"candid"`
  ObjectId string `avro:"objectId"`
  CutoutScience *Cutout `avro:"cutoutScience"`
  CutoutDifference *Cutout `avro:"cutoutDifference"`
}

// Global map, stamp type to extension name
var get_extension = map[string]string{
  "science": "_istamp.fits",
  "difference": "_dstamp.fits",
}

func createCutouts(directory string, candid string) map[string]*Cutout {
  // Holder for cutouts
  cutouts := make(map[string]*Cutout)
  // Fill cutout map
  for kind, _ := range get_extension {
    // Cutout name
    cutout_file_name := candid + get_extension[kind]
    // Read stamp data
    cutout_data, _ :=  ioutil.ReadFile(directory + "/" + cutout_file_name)
    // Create cutout object
    p_cutout := &Cutout{
      FileName: cutout_file_name,
      StampData: cutout_data,
    }
    // Append cutout to array
    cutouts[kind] = p_cutout
  }
  return cutouts
}

func createCandidate(data []interface{}) *Candidate {
  RA, _ := strconv.ParseFloat(data[0].(string), 64)
  Dec, _ := strconv.ParseFloat(data[1].(string), 64)
  Mag, _ := strconv.ParseFloat(data[2].(string), 64)
  Dmag, _ := strconv.ParseFloat(data[3].(string), 64)
  X, _ := strconv.ParseFloat(data[4].(string), 64)
  Y, _ := strconv.ParseFloat(data[5].(string), 64)
  Major, _ := strconv.ParseFloat(data[6].(string), 64)
  Minor, _ := strconv.ParseFloat(data[7].(string), 64)
  Phi, _ := strconv.ParseFloat(data[8].(string), 64)
  Det, _ := strconv.ParseFloat(data[9].(string), 64)
  ChiN, _ := strconv.ParseFloat(data[10].(string), 64)
  Pvr, _ := strconv.ParseFloat(data[11].(string), 64)
  Ptr, _ := strconv.ParseFloat(data[12].(string), 64)
  Pmv, _ := strconv.ParseFloat(data[13].(string), 64)
  Pkn, _ := strconv.ParseFloat(data[14].(string), 64)
  Pno, _ := strconv.ParseFloat(data[15].(string), 64)
  Pbn, _ := strconv.ParseFloat(data[16].(string), 64)
  Pcr, _ := strconv.ParseFloat(data[17].(string), 64)
  Pxt, _ := strconv.ParseFloat(data[18].(string), 64)
  Psc, _ := strconv.ParseFloat(data[19].(string), 64)
  Dup, _ := strconv.ParseFloat(data[20].(string), 64)
  WPflx, _ := strconv.ParseFloat(data[21].(string), 64)
  Dflx, _ := strconv.ParseFloat(data[22].(string), 64)
  Candid, _ := data[23].(string)
  Mjd, _ := strconv.ParseFloat(data[24].(string), 64)
  Filter, _ := data[25].(string)
  candidate := Candidate{
    Candid: Candid,
    RA: RA,
    Dec: Dec,
    Mag: Mag,
    Dmag: Dmag,
    X: X,
    Y: Y,
    Major: Major,
    Minor: Minor,
    Phi: Phi,
    Det: Det,
    ChiN: ChiN,
    Pvr: Pvr,
    Ptr: Ptr,
    Pmv: Pmv,
    Pkn: Pkn,
    Pno: Pno,
    Pbn: Pbn,
    Pcr: Pcr,
    Pxt: Pxt,
    Psc: Psc,
    Dup: Dup,
    WPflx: WPflx,
    Dflx: Dflx,
    Mjd: Mjd,
    Filter: Filter,
  }
  return &candidate
}

func createRecord(data []interface{}) *AtlasRecord {
  /*
   * Candidate fields are: RA, Dec, Mag, Dmag, X, Y, Major, Minor,
   * Phi, Det, ChiN, Pvr, Ptr, Pmv, Pkn, Pno, Pbn, Pxt, Pcr, Dup,
   * WPflx, Dflx, Mjd, Filter
   */
  // Float64 array to store candidate fields
  candidate_data := []interface{}{data[1]} // RA
  // Put the contents of the file in the data of the alert
  for i, element := range data[2:28] { // does not include 28
    real_count := i + 2
    // Skip candid and objectID
    if (real_count == 25) {
    } else {
      candidate_data = append(candidate_data, element)
    }
  }
  // Create candidate
  p_candidate := createCandidate(candidate_data)
  // Non candidate fields
  Schemavsn := string(data[0].(string))
  Publisher := "ATLAS"
  Candidate := p_candidate
  Candid := string(data[24].(string))
  ObjectId := string(data[25].(string))
  // data[26] is mjd,  data[27] is filter, those value goes in the candidate
  CutoutScience := data[28].(*Cutout)
  CutoutDifference := data[29].(*Cutout)
  // Create atlas record
  atlas_record := AtlasRecord{
    Schemavsn: Schemavsn,
    Publisher: Publisher,
    Candidate: Candidate,
    Candid: Candid,
    ObjectId: ObjectId,
    CutoutScience: CutoutScience,
    CutoutDifference: CutoutDifference,
  }
  return &atlas_record
}
