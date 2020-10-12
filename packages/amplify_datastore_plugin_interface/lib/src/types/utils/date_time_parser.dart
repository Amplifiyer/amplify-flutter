/*
 * Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import 'package:intl/intl.dart';
import 'package:date_time_format/date_time_format.dart';

/// In case the serialized date from different platforms come differently
/// Kotlin -> MMM d, yyyy h:mm:ss a
/// Dart -> ISO 8601 YYYY-MM-DDThh:mm:ssTZD
DateTime dateParser(String serializedDate) {
  if (serializedDate == null) {
    return null;
  }
  try {
    DateFormat kotlinFormat = new DateFormat("MMM d, yyyy h:mm:ss a");
    return kotlinFormat.parse(serializedDate);
  } on FormatException {
    try {
      return DateTime.parse(serializedDate);
    } on FormatException {
      return null;
    }
  }
}

String formatDateToISO8601(DateTime dateTime) {
  return dateTime == null
      ? null
      : DateTimeFormat.format(dateTime, format: DateTimeFormats.iso8601);
}
