// ownership. Elasticsearch B.V. licenses this file to you under
// the Apache License, Version 2.0 (the "License"); you may
// not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

// +build go1.9

package apmgopg

import (
	"github.com/go-pg/pg"

	"go.elastic.co/apm"
)

const elasticApmSpanKey = "go-apm-agent"

type QueryHook struct {
	Database string
	Username string

	UseFormattedQuery bool
}

func (qh *QueryHook) BeforeQuery(evt *pg.QueryEvent) {

	var sql string
	var err error

	if qh.UseFormattedQuery {
		sql, err = evt.FormattedQuery()
	} else {
		sql, err = evt.UnformattedQuery()
	}

	if err != nil {
		// todo: panic/logging ?
		return
	}

	span, _ := apm.StartSpan(evt.DB.Context(), apmutil.QuerySignarture(sql), "db.postgres.query")
	span.Context.SetDatabase(apm.DatabaseSpanContext{
		Statement: sql,

		// Static
		Type:     "sql",
		User:     qh.Username,
		Instance: qh.Database,
	})

	evt.Data[elasticApmSpanKey] = span
}

func (qh *QueryHook) AfterQuery(evt *pg.QueryEvent) {
	span, ok := evt.Data[elasticApmSpanKey]
	if !ok {
		return
	}

	if s, ok := span.(*apm.Span); ok {
		s.End()
	}
}
