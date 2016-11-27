FROM lsiobase/alpine
MAINTAINER sparklyballs

# add local files
COPY docker-java-home /usr/local/bin/docker-java-home

# package versions
ENV JAVA_VERSION 8u111
ENV JAVA_ALPINE_VERSION 8.111.14-r0
ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.5.8

# java environment settings
ENV LANG C.UTF-8
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk/jre
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

# tomcat environment settings
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME

# install java
RUN \
 chmod +x \
	/usr/local/bin/docker-java-home && \
 apk add --no-cache \
	openjdk8-jre="$JAVA_ALPINE_VERSION" && \
 [ "$JAVA_HOME" = "$(docker-java-home)" ] && \

# install build packages
 apk add --no-cache --virtual=build-dependencies \
	apr-dev \
	curl \
	gcc \
	libc-dev \
	make \
	"openjdk${JAVA_VERSION%%[-~bu]*}"="$JAVA_ALPINE_VERSION" \
	openssl-dev \
	tar && \

# install tomcat
 curl -o \
 "$CATALINA_HOME/tomcat.tar.gz" -L \
	"https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz" && \
 tar -xf tomcat.tar.gz --exclude=bin/*.bat --strip-components=1 && \
 rm tomcat.tar.gz* && \

# compile tomcat native
 mkdir -p \
	/tmp/tomcat && \
 tar -xf \
 bin/tomcat-native.tar.gz -C \
	/tmp/tomcat --strip-components=1 && \
 rm bin/tomcat-native.tar.gz && \
 cd /tmp/tomcat/native && \
 export CATALINA_HOME="$PWD" && \
 ./configure \
	--libdir="$TOMCAT_NATIVE_LIBDIR" \
	--prefix="$CATALINA_HOME" \
	--with-apr="$(which apr-1-config)" \
	--with-java-home="$(docker-java-home)" \
	--with-ssl=yes && \
 make -j$(getconf _NPROCESSORS_ONLN) && \
 make install && \
 runDeps="$( \
	scanelf --needed --nobanner --recursive "$TOMCAT_NATIVE_LIBDIR" \
	| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
	| sort -u \
	| xargs -r apk info --installed \
	| sort -u \
	)" && \
 apk add $runDeps && \

# cleanup
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/tmp/*

EXPOSE 8080
CMD ["catalina.sh", "run"]
