# See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

# This stage is used when running from VS in fast mode (Default for Debug configuration)
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
USER app
WORKDIR /app
EXPOSE 8080


# This stage is used to build the service project
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["OdataApp/OdataApp.csproj", "OdataApp/"]
RUN dotnet restore "./OdataApp/OdataApp.csproj"
COPY . .
WORKDIR "/src/OdataApp"
RUN dotnet build "./OdataApp.csproj" -c $BUILD_CONFIGURATION -o /app/build

# This stage is used to publish the service project to be copied to the final stage
FROM build AS publish
ARG BUILD_CONFIGURATION=Release

ARG GitVersion_SemVer
ENV env_GitVersion_SemVer $GitVersion_SemVer
ARG GitVersion_AssemblySemFileVer
ENV env_GitVersion_AssemblySemFileVer $GitVersion_AssemblySemFileVer
ARG GitVersion_AssemblySemVer
ENV env_GitVersion_AssemblySemVer $GitVersion_AssemblySemVer

RUN dotnet publish "./OdataApp.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false /p:Version=$GitVersion_SemVer /p:FileVersion=$GitVersion_AssemblySemFileVer /p:AssemblyVersion=$GitVersion_AssemblySemVer
#RUN dotnet publish "Cad4DevOps.ADO.Compliance.WebPortal.csproj" -c Release -o /app/publish /p:UseAppHost=false /p:Version=1.0.88 /p:FileVersion=1.0.88.8 /p:AssemblyVersion=1.0.88.9
#RUN dotnet publish "./OdataApp.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# This stage is used in production or when running from VS in regular mode (Default when not using the Debug configuration)
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "OdataApp.dll"]