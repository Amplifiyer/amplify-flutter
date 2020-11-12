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

import 'dart:collection';

import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:flutter/services.dart';
import 'package:amplify_datastore_plugin_interface/amplify_datastore_plugin_interface.dart';
import 'package:meta/meta.dart';

const MethodChannel _channel = MethodChannel('com.amazonaws.amplify/datastore');

/// An implementation of [AmplifyDataStore] that uses method channels.
class AmplifyDataStoreMethodChannel extends AmplifyDataStore {
  var _allModelsStreamFromMethodChannel = null;

  /// This method adds model schemas which is necessary to instantiate native plugins
  /// This is needed before the Amplify.configure() can be called, since the native
  /// plugins are needed to be added before that.
  Future<void> addModelSchemas(
      {@required List<ModelSchema> modelSchemas}) async {
    return _channel.invokeMethod('addModelSchemas', <String, dynamic>{
      'modelSchemas': modelSchemas.map((schema) => schema.toMap()).toList()
    });
  }

  /// This methods configure an event channel to carry datastore observe events. This
  /// can only be done after Amplify.configure() is called and before any observe()
  /// method is called.
  Future<void> configure({String configuration}) async {
    // First step to configure datastore is to setup an event channel for observe
    return _channel.invokeMethod('setupObserve', {});
  }

  @override
  Future<List<T>> query<T extends Model>(ModelType<T> modelType,
      {QueryPredicate where,
      QueryPagination pagination,
      List<QuerySortBy> sortBy}) async {
    try {
      final List<Map<dynamic, dynamic>> serializedResults =
          await _channel.invokeListMethod('query', <String, dynamic>{
        'modelName': modelType.modelName(),
        'queryPredicate': where?.serializeAsMap(),
        'queryPagination': pagination?.serializeAsMap(),
        'querySort':
            sortBy?.map((element) => element?.serializeAsMap())?.toList()
      });

      return serializedResults
          .map((serializedResult) => modelType.fromJson(
              new Map<String, dynamic>.from(
                  serializedResult["serializedData"])))
          .toList();
    } on PlatformException catch (e) {
      throw formatError(e);
    } on TypeError {
      throw DataStoreError.init(
          cause: "ERROR_FORMATTING_PLATFORM_CHANNEL_RESPONSE",
          errorMap: new LinkedHashMap.from(
              {"errorMessage": "Failed to deserialize query API results"}));
    }
  }

  @override
  Future<T> delete<T extends Model>(T model, {QueryPredicate when}) async {
    try {
      var modelJson = model.toJson();
      final Map<dynamic, dynamic> serializedResult =
          await _channel.invokeMapMethod('delete', <String, dynamic>{
        'modelName': model.instanceType.modelName(),
        'model': modelJson,
        'queryPredicate': when?.serializeAsMap(),
      });

      return model.instanceType.fromJson(
          new Map<String, dynamic>.from(serializedResult["serializedData"]));
    } on PlatformException catch (e) {
      throw formatError(e);
    } on TypeError {
      throw DataStoreError.init(
          cause: "ERROR_FORMATTING_PLATFORM_CHANNEL_RESPONSE",
          errorMap: new LinkedHashMap.from(
              {"errorMessage": "Failed to deserialize delete API results"}));
    }
  }

  @override
  Stream<SubscriptionEvent<T>> observe<T extends Model>(ModelType<T> modelType,
      {QueryPredicate where}) {
    if (modelType == null) {
      throw DataStoreError.init(
          cause: "ERROR_MALFORMED_REQUEST",
          errorMap: new LinkedHashMap.from(
              {"errorMessage": "modelType is a required input in observe()"}));
    }

    // Step #1. Open the event channel if it's not already open. Note
    // that there is only one event channel for all observe calls for all models
    const _eventChannel =
        EventChannel('com.amazonaws.amplify/datastore_observe_events');
    _allModelsStreamFromMethodChannel = _allModelsStreamFromMethodChannel ??
        _eventChannel.receiveBroadcastStream(0).map((event) {
          // Step #2. Deserialize events.
          return SubscriptionEvent.fromMap(event, modelType);
        }).cast<SubscriptionEvent<T>>();

    // Step #3. Apply client side filtering on the stream.
    // Currently only modelType filtering is supported.
    return _allModelsStreamFromMethodChannel.where((event) {
      var filterByModelType = event.item.instanceType == modelType;
      var filterByPredicate = where != null
          ? _evaluatePredicate(where, event.item as T, modelType)
          : true;
      return filterByPredicate && filterByModelType;
    }).asBroadcastStream();
  }

  bool _evaluatePredicate<T extends Model>(
      QueryPredicate where, T event, ModelType<T> modelType) {
    // TODO enable predicate level client side filtering of events
    return true;
  }

  DataStoreError formatError(PlatformException e) {
    LinkedHashMap eMap = new LinkedHashMap<String, dynamic>();
    e.details.forEach((k, v) => {eMap.putIfAbsent(k, () => v)});
    return DataStoreError.init(cause: e.message, errorMap: eMap);
  }
}
