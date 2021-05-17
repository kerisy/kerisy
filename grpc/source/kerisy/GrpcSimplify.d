/*
 * Kerisy - A high-level D Programming Language Web framework that encourages rapid development and clean, pragmatic design.
 *
 * Copyright (C) 2021, Kerisy.com
 *
 * Website: https://www.kerisy.com
 *
 * Licensed under the Apache-2.0 License.
 *
 */

module kerisy.GrpcSimplify;

import kerisy.provider.ServiceProvider;
import kerisy.provider.GrpcServiceProvider;

import grpc.GrpcServer;
import grpc.GrpcClient;

GrpcService grpcInstance() {
    return serviceContainer().resolve!GrpcService();
}
