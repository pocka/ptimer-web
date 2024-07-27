// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"bytes"
	"database/sql"
	"log"
	"math"
	"os"

	ptimerSQL "github.com/pocka/ptimer/sql"
	"github.com/youpy/go-wav"
	_ "modernc.org/sqlite"
)

const (
	sampleRate = 44100
	level      = 0.8
)

func main() {
	if err := os.Remove("sample.ptimer"); err != nil {
		log.Fatal(err)
	}

	db, err := sql.Open("sqlite", "sample.ptimer")
	if err != nil {
		log.Fatal(err)
	}

	if err := ptimerSQL.Init(db); err != nil {
		log.Fatal(err)
	}

	if _, err = db.Exec(`
INSERT INTO metadata (
	title,
	description,
	lang
) VALUES (
	"Sample timer",
	"This is a sample file for testing purpose.",
	"en-US"
);
`); err != nil {
		log.Fatal(err)
	}

	sinWave, err := generateSineWave(5000, 1)
	if err != nil {
		log.Fatal(err)
	}

	if _, err := db.Exec(`
INSERT OR ABORT INTO asset (
	name,
	mime,
	data
) VALUES (
	"sin.wav",
	"audio/wav",
	?
);
`, sinWave); err != nil {
		log.Fatal(err)
	}

	if _, err := db.Exec(`
INSERT OR ABORT INTO step (
	title,
	description,
	'index'
) VALUES (
	"Step 1",
	"Manual step",
	1
);

INSERT OR ABORT INTO step (
	title,
	description,
	sound,
	duration_seconds,
	'index'
) VALUES (
	"Step 2",
	"Timer step with sound",
	1,
	2,
	2
);
`); err != nil {
		log.Fatal(err)
	}
}

func generateSineWave(frequencyLike int, durationInSeconds int) ([]byte, error) {
	numSamples := sampleRate * durationInSeconds

	samples := make([]wav.Sample, numSamples)

	for i := range samples {
		y := math.Sin(float64(i)/float64(sampleRate)*float64(frequencyLike)) * math.MaxInt16 * level
		p := float64(i) / float64(numSamples)

		samples[i] = wav.Sample{
			Values: [2]int{
				int(math.Round(y * p)),
				int(math.Round(y * (1 - p))),
			},
		}
	}

	var buf bytes.Buffer
	wavWriter := wav.NewWriter(&buf, uint32(numSamples), 2, sampleRate, 16)

	if err := wavWriter.WriteSamples(samples); err != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}
